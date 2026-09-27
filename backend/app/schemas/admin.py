from typing import Optional

from pydantic import BaseModel, Field


class AppSettingsOut(BaseModel):
    restaurant_name: str
    currency: str
    tax_rate: float
    service_fee_cents: int
    is_accepting_orders: bool
    avg_prep_minutes: int
    points_per_dollar: int
    point_value_cents: int
    min_points_to_redeem: int
    max_redeem_percent: int
    tier_thresholds: dict[str, int]


class AppSettingsUpdate(BaseModel):
    restaurant_name: Optional[str] = Field(None, max_length=80)
    tax_rate: Optional[float] = Field(None, ge=0, le=0.5)
    service_fee_cents: Optional[int] = Field(None, ge=0)
    is_accepting_orders: Optional[bool] = None
    avg_prep_minutes: Optional[int] = Field(None, ge=1, le=120)
    points_per_dollar: Optional[int] = Field(None, ge=0)
    point_value_cents: Optional[int] = Field(None, ge=1)
    min_points_to_redeem: Optional[int] = Field(None, ge=0)
    max_redeem_percent: Optional[int] = Field(None, ge=0, le=100)
    tier_thresholds: Optional[dict[str, int]] = None


class KitchenJobStatusIn(BaseModel):
    status: str = Field(description="cooking | done | failed")
    message: Optional[str] = Field(None, max_length=300)
    progress: Optional[int] = Field(None, ge=0, le=100)
