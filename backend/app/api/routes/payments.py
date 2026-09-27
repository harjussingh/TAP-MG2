from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.deps import get_order_for_viewer
from app.core.config import settings
from app.core.database import get_db
from app.schemas.order import OrderOut
from app.services import order_service
from app.services.payment_service import parse_stripe_event
from app.services.settings_service import get_app_settings
from app.utils.helpers import utcnow

router = APIRouter(prefix="/payments", tags=["Payments"])


@router.get("/config")
async def payment_config(db=Depends(get_db)):
    """What the frontend needs to render the payment step."""
    cfg = await get_app_settings(db)
    return {"provider": settings.PAYMENT_PROVIDER, "publishable_key": settings.STRIPE_PUBLISHABLE_KEY,
            "currency": cfg["currency"], "methods": ["card", "cash", "pay_at_counter"]}


@router.post("/{order_id}/mock-confirm", response_model=OrderOut)
async def mock_confirm(order=Depends(get_order_for_viewer), db=Depends(get_db)):
    """DEVELOPMENT ONLY (PAYMENT_PROVIDER=mock): simulates a successful card payment."""
    if settings.PAYMENT_PROVIDER != "mock":
        raise HTTPException(404, "Not found")
    if order["payment"]["method"] != "card":
        raise HTTPException(409, "Order is not a card order")
    return order_service.order_out(await order_service.mark_paid(db, order, None))


@router.post("/stripe/webhook", include_in_schema=True)
async def stripe_webhook(request: Request, db=Depends(get_db)):
    """Configure this URL in the Stripe dashboard (events: payment_intent.succeeded, payment_intent.payment_failed)."""
    event = parse_stripe_event(await request.body(), request.headers.get("stripe-signature"))
    intent = event["data"]["object"]
    order = await db.orders.find_one({"payment.provider_ref": intent["id"]})
    if not order:
        return {"received": True}
    if event["type"] == "payment_intent.succeeded":
        await order_service.mark_paid(db, order, None, intent["id"])
    elif event["type"] == "payment_intent.payment_failed":
        await db.orders.update_one({"_id": order["_id"]},
                                   {"$set": {"payment.status": "failed", "updated_at": utcnow()}})
    return {"received": True}
