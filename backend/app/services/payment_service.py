"""Payment provider abstraction: 'mock' (development) or 'stripe'."""
import logging

from fastapi import HTTPException
from starlette.concurrency import run_in_threadpool

from app.core.config import settings

logger = logging.getLogger(__name__)


def _stripe():
    import stripe

    if not settings.STRIPE_SECRET_KEY:
        raise HTTPException(500, "Stripe is not configured")
    stripe.api_key = settings.STRIPE_SECRET_KEY
    return stripe


async def create_card_payment(order: dict) -> dict:
    """Returns {provider, provider_ref, client_secret, ...} for a card order."""
    if settings.PAYMENT_PROVIDER == "stripe":
        stripe = _stripe()
        intent = await run_in_threadpool(
            stripe.PaymentIntent.create,
            amount=order["pricing"]["total_cents"],
            currency=order["currency"],
            metadata={"order_id": order["_id"], "order_number": str(order["order_number"])},
            automatic_payment_methods={"enabled": True},
        )
        return {"provider": "stripe", "provider_ref": intent.id, "client_secret": intent.client_secret,
                "publishable_key": settings.STRIPE_PUBLISHABLE_KEY}
    return {"provider": "mock", "provider_ref": f"mock_{order['_id']}", "client_secret": None,
            "mock_confirm_url": f"{settings.API_PREFIX}/payments/{order['_id']}/mock-confirm"}


async def refund(order: dict) -> None:
    payment = order["payment"]
    if payment.get("provider") == "stripe" and payment.get("provider_ref"):
        stripe = _stripe()
        await run_in_threadpool(stripe.Refund.create, payment_intent=payment["provider_ref"])
    # mock / cash refunds are recorded only


def parse_stripe_event(payload: bytes, signature: str | None):
    stripe = _stripe()
    if not settings.STRIPE_WEBHOOK_SECRET:
        raise HTTPException(500, "STRIPE_WEBHOOK_SECRET not configured")
    try:
        return stripe.Webhook.construct_event(payload, signature, settings.STRIPE_WEBHOOK_SECRET)
    except Exception:  # noqa: BLE001
        raise HTTPException(400, "Invalid Stripe signature")
