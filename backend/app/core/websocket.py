"""WebSocket connection manager.

Channels:
  order:{order_id}  -> customer order-tracking screen
  staff             -> staff/admin live order board
  kitchen           -> robot kitchen controller

If Redis is configured, messages are published through Redis pub/sub so that every
uvicorn worker / server instance forwards them to its own connected sockets.
"""
import asyncio
import json
import logging
from collections import defaultdict

from fastapi import WebSocket
from fastapi.encoders import jsonable_encoder

from app.core.redis_client import get_redis

logger = logging.getLogger(__name__)
_PREFIX = "ws:"


class ConnectionManager:
    def __init__(self) -> None:
        self.channels: dict[str, set[WebSocket]] = defaultdict(set)
        self._listener: asyncio.Task | None = None

    async def connect(self, channel: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.channels[channel].add(websocket)

    def disconnect(self, channel: str, websocket: WebSocket) -> None:
        self.channels[channel].discard(websocket)
        if not self.channels[channel]:
            self.channels.pop(channel, None)

    async def _send_local(self, channel: str, message: dict) -> None:
        for ws in list(self.channels.get(channel, ())):
            try:
                await ws.send_json(message)
            except Exception:  # noqa: BLE001
                self.disconnect(channel, ws)

    async def publish(self, channel: str, event: str, data) -> None:
        message = {"event": event, "data": jsonable_encoder(data)}
        r = get_redis()
        if r is not None:
            try:
                await r.publish(_PREFIX + channel, json.dumps(message))
                return
            except Exception as exc:  # noqa: BLE001
                logger.warning("Redis publish failed, sending locally: %s", exc)
        await self._send_local(channel, message)

    async def start(self) -> None:
        if get_redis() is not None and self._listener is None:
            self._listener = asyncio.create_task(self._listen())

    async def stop(self) -> None:
        if self._listener:
            self._listener.cancel()
            self._listener = None

    async def _listen(self) -> None:
        r = get_redis()
        pubsub = r.pubsub()
        await pubsub.psubscribe(_PREFIX + "*")
        try:
            async for msg in pubsub.listen():
                if msg.get("type") != "pmessage":
                    continue
                channel = msg["channel"][len(_PREFIX):]
                try:
                    await self._send_local(channel, json.loads(msg["data"]))
                except Exception as exc:  # noqa: BLE001
                    logger.warning("WS forward failed: %s", exc)
        except asyncio.CancelledError:
            await pubsub.aclose()


ws_manager = ConnectionManager()
