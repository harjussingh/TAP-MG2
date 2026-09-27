from fastapi import APIRouter, Depends, Query

from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.common import Page
from app.schemas.loyalty import LoyaltySummary, LoyaltyTxnOut
from app.services.loyalty_service import tier_info
from app.services.settings_service import get_app_settings
from app.utils.helpers import doc_out, page_response

router = APIRouter(prefix="/loyalty", tags=["Loyalty"])


@router.get("/summary", response_model=LoyaltySummary)
async def summary(user=Depends(get_current_user), db=Depends(get_db)):
    cfg = await get_app_settings(db)
    tier, nxt, to_next = tier_info(user.get("lifetime_points", 0), cfg["tier_thresholds"])
    points = user.get("loyalty_points", 0)
    return {
        "points": points, "lifetime_points": user.get("lifetime_points", 0), "tier": tier, "next_tier": nxt,
        "points_to_next_tier": to_next, "points_per_dollar": cfg["points_per_dollar"],
        "point_value_cents": cfg["point_value_cents"], "min_points_to_redeem": cfg["min_points_to_redeem"],
        "max_redeem_percent": cfg["max_redeem_percent"],
        "redeemable_value_cents": points * cfg["point_value_cents"] if points >= cfg["min_points_to_redeem"] else 0,
    }


@router.get("/transactions", response_model=Page[LoyaltyTxnOut])
async def transactions(page: int = Query(1, ge=1), size: int = Query(20, ge=1, le=100),
                       user=Depends(get_current_user), db=Depends(get_db)):
    query = {"user_id": user["_id"]}
    total = await db.loyalty_transactions.count_documents(query)
    docs = await db.loyalty_transactions.find(query).sort("created_at", -1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([doc_out(d) for d in docs], total, page, size)
