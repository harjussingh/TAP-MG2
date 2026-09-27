"""Runtime business settings stored in the `app_settings` collection (editable by admins)."""
from app.core.config import settings
from app.utils.helpers import utcnow


def _defaults() -> dict:
    return {
        "restaurant_name": "RoboKitchen",
        "currency": settings.CURRENCY,
        "tax_rate": settings.TAX_RATE,
        "service_fee_cents": settings.SERVICE_FEE_CENTS,
        "is_accepting_orders": True,
        "avg_prep_minutes": 4,
        "points_per_dollar": settings.POINTS_PER_DOLLAR,
        "point_value_cents": settings.POINT_VALUE_CENTS,
        "min_points_to_redeem": settings.MIN_POINTS_TO_REDEEM,
        "max_redeem_percent": settings.MAX_REDEEM_PERCENT,
        "tier_thresholds": {
            "bronze": 0,
            "silver": settings.SILVER_THRESHOLD,
            "gold": settings.GOLD_THRESHOLD,
            "platinum": settings.PLATINUM_THRESHOLD,
        },
    }


async def get_app_settings(db) -> dict:
    doc = await db.app_settings.find_one({"_id": "global"}) or {}
    merged = {**_defaults(), **{k: v for k, v in doc.items() if k not in ("_id", "updated_at", "updated_by")}}
    return merged


async def update_app_settings(db, changes: dict, actor_id: str) -> dict:
    if changes:
        await db.app_settings.update_one(
            {"_id": "global"},
            {"$set": {**changes, "updated_at": utcnow(), "updated_by": actor_id}},
            upsert=True,
        )
    return await get_app_settings(db)
