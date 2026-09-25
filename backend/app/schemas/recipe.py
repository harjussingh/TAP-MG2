from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.schemas.menu import PricedSelection, SelectionIn


class RecipeIn(BaseModel):
    name: str = Field(min_length=1, max_length=60)
    menu_item_id: str
    selections: list[SelectionIn] = []
    special_instructions: Optional[str] = Field(None, max_length=300)


class RecipeUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=60)
    selections: Optional[list[SelectionIn]] = None
    special_instructions: Optional[str] = Field(None, max_length=300)


class RecipeOut(BaseModel):
    id: str
    name: str
    menu_item_id: str
    menu_item_name: str
    selections: list[PricedSelection] = []
    special_instructions: Optional[str] = None
    current_price_cents: Optional[int] = None
    calories: Optional[int] = None
    is_available: bool
    unavailable_reason: Optional[str] = None
    times_ordered: int = 0
    created_at: datetime
