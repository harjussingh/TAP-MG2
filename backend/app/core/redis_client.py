"""Optional Redis connection. The app works without Redis (single process)."""
import logging

from redis import asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger(__name__)
_redis: aioredis.Redis | None = None


async def connect_redis() -> None:
    global _redis
    if not settings.REDIS_URL:
        logger.info("REDIS_URL not set - using in-memory rate limiting and WebSocket fan-out")
        return
    try:
        client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
        await client.ping()
        _redis = client
        logger.info("Redis connected")
    except Exception as exc:  # noqa: BLE001
        logger.warning("Redis unavailable (%s) - falling back to in-memory mode", exc)
        _redis = None


def get_redis() -> aioredis.Redis | None:
    return _redis


async def close_redis() -> None:
    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
