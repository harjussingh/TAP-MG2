from fastapi import HTTPException
from pymongo import ReturnDocument

from app.services.settings_service import get_app_settings
from app.utils.helpers import new_id, utcnow

TIER_ORDER = ["bronze", "silver", "gold", "platinum"]


def tier_info(lifetime: int, thresholds: dict) -> tuple[str, str | None, int]:
    tier = "bronze"
    for t in TIER_ORDER:
        if lifetime >= thresholds.get(t, 0):
            tier = t
    idx = TIER_ORDER.index(tier)
    if idx + 1 < len(TIER_ORDER):
        nxt = TIER_ORDER[idx + 1]
        return tier, nxt, max(0, thresholds[nxt] - lifetime)
    return tier, None, 0


async def _record(db, user: dict, txn_type: str, points: int, description: str, order_id: str | None = None):
    await db.loyalty_transactions.insert_one({
        "_id": new_id("lty"), "user_id": user["_id"], "type": txn_type, "points": points,
        "balance_after": user.get("loyalty_points", 0), "order_id": order_id,
        "description": description, "created_at": utcnow(),
    })


async def _update_tier(db, user: dict) -> dict:
    cfg = await get_app_settings(db)
    tier, _, _ = tier_info(user.get("lifetime_points", 0), cfg["tier_thresholds"])
    if tier != user.get("loyalty_tier"):
        await db.users.update_one({"_id": user["_id"]}, {"$set": {"loyalty_tier": tier}})
        user["loyalty_tier"] = tier
    return user


async def redeem(db, user_id: str, points: int, order_id: str) -> None:
    user = await db.users.find_one_and_update(
        {"_id": user_id, "loyalty_points": {"$gte": points}},
        {"$inc": {"loyalty_points": -points}}, return_document=ReturnDocument.AFTER,
    )
    if not user:
        raise HTTPException(409, "Not enough loyalty points")
    await _record(db, user, "redeem", -points, "Points redeemed on order", order_id)


async def refund_redeemed(db, user_id: str, points: int, order_id: str) -> None:
    user = await db.users.find_one_and_update(
        {"_id": user_id}, {"$inc": {"loyalty_points": points}}, return_document=ReturnDocument.AFTER)
    if user:
        await _record(db, user, "refund", points, "Redeemed points returned (order cancelled)", order_id)


async def award_for_order(db, order: dict) -> int:
    if not order.get("user_id") or order.get("points_earned"):
        return 0
    cfg = await get_app_settings(db)
    spend = order["pricing"]["subtotal_cents"] - order["pricing"]["discount_cents"]
    points = (spend // 100) * cfg["points_per_dollar"]
    if points <= 0:
        return 0
    user = await db.users.find_one_and_update(
        {"_id": order["user_id"]}, {"$inc": {"loyalty_points": points, "lifetime_points": points}},
        return_document=ReturnDocument.AFTER)
    if not user:
        return 0
    await _update_tier(db, user)
    await _record(db, user, "earn", points, f"Earned on order #{order['order_number']}", order["_id"])
    await db.orders.update_one({"_id": order["_id"]}, {"$set": {"points_earned": points}})
    return points


async def reverse_earned(db, order: dict) -> None:
    points = order.get("points_earned", 0)
    if not order.get("user_id") or not points:
        return
    user = await db.users.find_one_and_update(
        {"_id": order["user_id"]}, {"$inc": {"loyalty_points": -points, "lifetime_points": -points}},
        return_document=ReturnDocument.AFTER)
    if user:
        await _update_tier(db, user)
        await _record(db, user, "reverse", -points, f"Points reversed (order #{order['order_number']} refunded)",
                      order["_id"])
    await db.orders.update_one({"_id": order["_id"]}, {"$set": {"points_earned": 0}})


async def adjust(db, user_id: str, points: int, reason: str) -> dict:
    inc = {"loyalty_points": points}
    if points > 0:
        inc["lifetime_points"] = points
    user = await db.users.find_one_and_update(
        {"_id": user_id, "loyalty_points": {"$gte": -points if points < 0 else 0}}, {"$inc": inc},
        return_document=ReturnDocument.AFTER)
    if not user:
        raise HTTPException(409, "User not found or balance would become negative")
    await _update_tier(db, user)
    await _record(db, user, "adjust", points, reason)
    return user
