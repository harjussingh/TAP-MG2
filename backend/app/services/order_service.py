"""Order lifecycle: checkout, status transitions, payment confirmation, cancellation."""
import logging
from datetime import timedelta

from fastapi import BackgroundTasks, HTTPException
from pymongo import ReturnDocument

from app.core.security import generate_token, hash_token
from app.core.websocket import ws_manager
from app.services import email_service, kitchen_service, loyalty_service, payment_service
from app.services.cart_service import cart_view
from app.services.settings_service import get_app_settings
from app.utils.helpers import doc_out, new_id, utcnow

logger = logging.getLogger(__name__)

TRANSITIONS = {
    "pending_payment": {"confirmed", "cancelled"},
    "confirmed": {"preparing", "ready", "cancelled"},
    "preparing": {"ready", "cancelled"},
    "ready": {"completed"},
    "completed": set(),
    "cancelled": set(),
}


def order_out(order: dict) -> dict:
    return doc_out(order)


async def next_order_number(db) -> int:
    doc = await db.counters.find_one_and_update(
        {"_id": "order_number"}, {"$inc": {"seq": 1}}, upsert=True, return_document=ReturnDocument.AFTER)
    return 1000 + doc["seq"]


async def _broadcast(order: dict, event: str = "order.updated") -> None:
    data = order_out(order)
    await ws_manager.publish(f"order:{order['_id']}", event, data)
    await ws_manager.publish("staff", event, data)


async def checkout(db, cart: dict, user: dict | None, data, background: BackgroundTasks) -> tuple[dict, str, dict]:
    cfg = await get_app_settings(db)
    if not cfg["is_accepting_orders"]:
        raise HTTPException(409, "The kitchen is not accepting orders right now")
    if not cart["items"]:
        raise HTTPException(400, "Your cart is empty")
    if not user and not (data.customer_name or "").strip():
        raise HTTPException(422, "customer_name is required for guest checkout")
    if data.redeem_points and not user:
        raise HTTPException(422, "Log in to redeem loyalty points")

    view = await cart_view(db, cart, user, data.redeem_points, data.tip_cents)
    if view["has_errors"]:
        problems = "; ".join(f"{li['name']}: {li['error']}" for li in view["items"] if li.get("error"))
        raise HTTPException(409, f"Some items in your cart need attention - {problems}")

    now = utcnow()
    order_id = new_id("ord")
    access_token = generate_token(24)
    is_card = data.payment_method.value == "card"
    order = {
        "_id": order_id,
        "order_number": await next_order_number(db),
        "status": "pending_payment" if is_card else "confirmed",
        "order_type": view["order_type"],
        "table": view["table"],
        "user_id": user["_id"] if user else None,
        "customer": {
            "name": (data.customer_name or (user or {}).get("full_name") or "").strip() or None,
            "email": str(data.customer_email) if data.customer_email else (user or {}).get("email"),
            "phone": data.customer_phone or (user or {}).get("phone"),
        },
        "items": [{k: v for k, v in li.items() if k != "error"} for li in view["items"]],
        "pricing": view["totals"],
        "currency": view["currency"],
        "payment": {"method": data.payment_method.value, "status": "pending" if is_card else "unpaid",
                    "provider": None, "provider_ref": None, "paid_at": None},
        "notes": data.notes,
        "status_history": [{"status": "pending_payment" if is_card else "confirmed", "at": now,
                            "by": user["_id"] if user else "guest", "note": "Order placed"}],
        "estimated_ready_at": None,
        "points_earned": 0,
        "has_review": False,
        "access_token_hash": hash_token(access_token),
        "created_at": now,
        "updated_at": now,
    }

    points = view["totals"]["points_redeemed"]
    if points:
        await loyalty_service.redeem(db, user["_id"], points, order_id)
    try:
        await db.orders.insert_one(order)
    except Exception:
        if points:
            await loyalty_service.refund_redeemed(db, user["_id"], points, order_id)
        raise

    await db.carts.update_one({"_id": cart["_id"]}, {"$set": {"items": [], "updated_at": now}})

    payment_action = {"provider": "offline", "requires_action": False}
    if is_card:
        pay = await payment_service.create_card_payment(order)
        order["payment"].update(provider=pay["provider"], provider_ref=pay["provider_ref"])
        await db.orders.update_one({"_id": order_id}, {"$set": {"payment": order["payment"]}})
        payment_action = {"requires_action": True, **{k: v for k, v in pay.items() if k != "provider_ref"}}
        await _broadcast(order, "order.created")
    else:
        order = await on_confirmed(db, order)
        await _broadcast(order, "order.created")

    background.add_task(email_service.send_order_confirmation, order)
    return order, access_token, payment_action


async def on_confirmed(db, order: dict) -> dict:
    """Send the order to the robot kitchen and compute an ETA."""
    cfg = await get_app_settings(db)
    ahead = await kitchen_service.jobs_ahead(db)
    own = sum(li.get("prep_time_seconds", 180) * li["quantity"] for li in order["items"])
    eta = utcnow() + timedelta(seconds=ahead * cfg["avg_prep_minutes"] * 60 + own)
    await kitchen_service.create_job(db, order)
    await db.orders.update_one({"_id": order["_id"]}, {"$set": {"estimated_ready_at": eta}})
    order["estimated_ready_at"] = eta
    return order


async def change_status(db, order: dict, new_status: str, actor: dict | None, note: str | None = None,
                        force: bool = False) -> dict:
    current = order["status"]
    if new_status == current:
        return order
    if not force and new_status not in TRANSITIONS.get(current, set()):
        raise HTTPException(409, f"Cannot change order from '{current}' to '{new_status}'")
    now = utcnow()
    event = {"status": new_status, "at": now, "by": actor["_id"] if actor else "system", "note": note}
    updated = await db.orders.find_one_and_update(
        {"_id": order["_id"], "status": current},
        {"$set": {"status": new_status, "updated_at": now, **({"cancel_reason": note} if new_status == "cancelled" else {})},
         "$push": {"status_history": event}},
        return_document=ReturnDocument.AFTER,
    )
    if not updated:
        raise HTTPException(409, "Order was updated by someone else, please refresh")

    if new_status == "confirmed":
        updated = await on_confirmed(db, updated)
    elif new_status == "cancelled":
        await kitchen_service.cancel_jobs_for_order(db, updated["_id"])
        pts = updated["pricing"].get("points_redeemed", 0)
        if updated.get("user_id") and pts:
            await loyalty_service.refund_redeemed(db, updated["user_id"], pts, updated["_id"])
    elif new_status == "ready":
        await email_service.send_order_ready(updated)
    elif new_status == "completed":
        if updated["payment"]["status"] == "paid" or updated["payment"]["method"] != "card":
            earned = await loyalty_service.award_for_order(db, updated)
            updated["points_earned"] = earned or updated.get("points_earned", 0)

    await _broadcast(updated)
    return updated


async def mark_paid(db, order: dict, actor: dict | None, provider_ref: str | None = None) -> dict:
    if order["payment"]["status"] == "paid":
        return order
    if order["status"] == "cancelled":
        raise HTTPException(409, "Order is cancelled")
    now = utcnow()
    upd = {"payment.status": "paid", "payment.paid_at": now, "updated_at": now}
    if provider_ref:
        upd["payment.provider_ref"] = provider_ref
    order = await db.orders.find_one_and_update({"_id": order["_id"]}, {"$set": upd},
                                                return_document=ReturnDocument.AFTER)
    if order["status"] == "pending_payment":
        order = await change_status(db, order, "confirmed", actor, "Payment received")
    else:
        await _broadcast(order)
    return order


async def refund_order(db, order: dict, actor: dict, reason: str | None) -> dict:
    if order["payment"]["status"] != "paid":
        raise HTTPException(409, "Only paid orders can be refunded")
    await payment_service.refund(order)
    await loyalty_service.reverse_earned(db, order)
    order = await db.orders.find_one_and_update(
        {"_id": order["_id"]}, {"$set": {"payment.status": "refunded", "updated_at": utcnow()}},
        return_document=ReturnDocument.AFTER)
    if order["status"] not in ("completed", "cancelled"):
        order = await change_status(db, order, "cancelled", actor, reason or "Refunded", force=True)
    else:
        await _broadcast(order)
    return order
