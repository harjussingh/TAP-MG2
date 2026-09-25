from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field

from app.models.enums import OrderStatus, OrderType, PaymentMethod, PaymentStatus
from app.schemas.cart import CartLineOut, Totals
from app.schemas.table import TableRef


class CheckoutIn(BaseModel):
    payment_method: PaymentMethod
    tip_cents: int = Field(0, ge=0, le=100_000)
    redeem_points: int = Field(0, ge=0)
    customer_name: Optional[str] = Field(None, max_length=100, description="Required for guests")
    customer_email: Optional[EmailStr] = None
    customer_phone: Optional[str] = Field(None, max_length=30)
    notes: Optional[str] = Field(None, max_length=500)


class Customer(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None


class PaymentInfo(BaseModel):
    method: PaymentMethod
    status: PaymentStatus
    provider: Optional[str] = None
    provider_ref: Optional[str] = None
    paid_at: Optional[datetime] = None


class StatusEvent(BaseModel):
    status: OrderStatus
    at: datetime
    by: Optional[str] = None
    note: Optional[str] = None


class OrderOut(BaseModel):
    id: str
    order_number: int
    status: OrderStatus
    order_type: OrderType
    table: Optional[TableRef] = None
    user_id: Optional[str] = None
    customer: Customer
    items: list[CartLineOut]
    pricing: Totals
    currency: str
    payment: PaymentInfo
    notes: Optional[str] = None
    status_history: list[StatusEvent] = []
    estimated_ready_at: Optional[datetime] = None
    points_earned: int = 0
    has_review: bool = False
    cancel_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class PaymentAction(BaseModel):
    provider: str
    requires_action: bool
    client_secret: Optional[str] = None
    publishable_key: Optional[str] = None
    mock_confirm_url: Optional[str] = None


class CheckoutOut(BaseModel):
    order: OrderOut
    order_access_token: str = Field(description="Keep this on the device: lets guests view/track/cancel/review the order")
    payment: PaymentAction


class OrderStatusUpdate(BaseModel):
    status: OrderStatus
    note: Optional[str] = Field(None, max_length=300)


class CancelIn(BaseModel):
    reason: Optional[str] = Field(None, max_length=300)


class ReorderOut(BaseModel):
    added: int
    skipped: list[str]
