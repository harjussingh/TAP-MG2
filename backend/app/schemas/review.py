from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class ItemRatingIn(BaseModel):
    menu_item_id: str
    rating: int = Field(ge=1, le=5)


class ReviewIn(BaseModel):
    order_id: str
    rating: int = Field(ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=1000)
    tags: list[str] = Field([], description="Quick feedback chips, e.g. 'fast', 'tasty'")
    item_ratings: list[ItemRatingIn] = []


class ReviewOut(BaseModel):
    id: str
    order_id: str
    order_number: Optional[int] = None
    user_id: Optional[str] = None
    author_name: str
    rating: int
    comment: Optional[str] = None
    tags: list[str] = []
    item_ratings: list[ItemRatingIn] = []
    is_visible: bool = True
    staff_reply: Optional[str] = None
    created_at: datetime


class ReviewModerate(BaseModel):
    is_visible: Optional[bool] = None
    staff_reply: Optional[str] = Field(None, max_length=1000)


class ItemReviewSummary(BaseModel):
    menu_item_id: str
    rating_avg: Optional[float]
    rating_count: int
