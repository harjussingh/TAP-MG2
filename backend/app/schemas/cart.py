from typing import Optional

from pydantic import BaseModel, Field

from app.models.enums import OrderType
from app.schemas.menu import PricedLine, SelectionIn
from app.schemas.table import TableRef


class CartItemIn(BaseModel):
    menu_item_id: str
    quantity: int = Field(1, ge=1, le=20)
    selections: list[SelectionIn] = []
    special_instructions: Optional[str] = Field(None, max_length=300)


class CartItemUpdate(BaseModel):
    quantity: Optional[int] = Field(None, ge=1, le=20)
    selections: Optional[list[SelectionIn]] = None
    special_instructions: Optional[str] = Field(None, max_length=300)


class CartContextIn(BaseModel):
    table_code: Optional[str] = Field(None, description="Code from the scanned QR. null = no table")
    order_type: OrderType = OrderType.dine_in


class CartLineOut(PricedLine):
    line_id: str
    error: Optional[str] = None


class Totals(BaseModel):
    subtotal_cents: int
    discount_cents: int = 0
    points_redeemed: int = 0
    tax_rate: float
    tax_cents: int
    service_fee_cents: int
    tip_cents: int = 0
    total_cents: int


class CartOut(BaseModel):
    id: str
    items: list[CartLineOut]
    item_count: int
    table: Optional[TableRef] = None
    order_type: OrderType
    totals: Totals
    currency: str
    has_errors: bool
