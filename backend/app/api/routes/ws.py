"""WebSocket endpoints. Send the text "ping" to receive "pong" (keep-alive)."""
import secrets

from fastapi import APIRouter, HTTPException, Query, WebSocket, WebSocketDisconnect
from fastapi.encoders import jsonable_encoder

from app.api.deps import can_view_order
from app.core.config import settings
from app.core.database import get_db
from app.core.security import decode_token
from app.core.websocket import ws_manager
from app.services.order_service import order_out

router = APIRouter(tags=["WebSockets"])


async def _user_from_jwt(db, token: str):
    try:
        payload = decode_token(token, "access")
    except HTTPException:
        return None
    return await db.users.find_one({"_id": payload["sub"], "is_active": True})


async def _serve(websocket: WebSocket, channel: str, first_message: dict | None = None):
    await ws_manager.connect(channel, websocket)
    try:
        if first_message:
            await websocket.send_json(jsonable_encoder(first_message))
        while True:
            msg = await websocket.receive_text()
            if msg == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        ws_manager.disconnect(channel, websocket)


@router.websocket("/ws/orders/{order_id}")
async def ws_order(websocket: WebSocket, order_id: str, token: str = Query(...)):
    """Customer tracking. `token` = the guest order_access_token OR a JWT access token."""
    db = get_db()
    order = await db.orders.find_one({"_id": order_id})
    user = None if not order else await _user_from_jwt(db, token)
    if not order or not can_view_order(order, user, token):
        await websocket.close(code=4403)
        return
    await _serve(websocket, f"order:{order_id}", {"event": "order.snapshot", "data": order_out(order)})


@router.websocket("/ws/staff")
async def ws_staff(websocket: WebSocket, token: str = Query(...)):
    """Staff/admin live board: order.created, order.updated, job.updated, job.failed, menu.availability..."""
    user = await _user_from_jwt(get_db(), token)
    if not user or user["role"] not in ("staff", "admin"):
        await websocket.close(code=4403)
        return
    await _serve(websocket, "staff")


@router.websocket("/ws/kitchen")
async def ws_kitchen(websocket: WebSocket, key: str = Query(...)):
    """Robot controller push channel: job.created, job.updated, job.cancelled."""
    if not secrets.compare_digest(key, settings.KITCHEN_API_KEY):
        await websocket.close(code=4403)
        return
    await _serve(websocket, "kitchen")
