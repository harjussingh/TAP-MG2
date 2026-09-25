from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.models.enums import LoyaltyTxnType


class LoyaltySummary(BaseModel):
    points: int
    lifetime_points: int
    tier: str
    next_tier: Optional[str]
    points_to_next_tier: int
    points_per_dollar: int
    point_value_cents: int
    min_points_to_redeem: int
    max_redeem_percent: int
    redeemable_value_cents: int


class LoyaltyTxnOut(BaseModel):
    id: str
    type: LoyaltyTxnType
    points: int
    balance_after: int
    order_id: Optional[str] = None
    description: str
    created_at: datetime


class LoyaltyAdjustIn(BaseModel):
    points: int = Field(description="Positive to add, negative to remove")
    reason: str = Field(min_length=3, max_length=200)
