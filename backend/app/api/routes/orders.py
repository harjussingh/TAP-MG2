from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query

from app.api.deps import get_current_user, get_current_user_optional, get_order_for_viewer, get_session_id
from app.core.database import get_db
from app.schemas.common import Page
from app.schemas.order import CancelIn, CheckoutIn, CheckoutOut, OrderOut, ReorderOut
from app.services import order_service
from app.services.cart_service import add_line, get_or_create_cart, owner_key, save_cart
from app.utils.helpers import page_response

router = APIRouter(prefix="/orders", tags=["Orders"])


@router.post("/checkout", response_model=CheckoutOut, status_code=201)
async def checkout(data: CheckoutIn, background: BackgroundTasks, user=Depends(get_current_user_optional),
                   session_id=Depends(get_session_id), db=Depends(get_db)):
    """Turn the current cart into an order.

    - `card`: order is `pending_payment` until the payment succeeds (Stripe webhook or mock-confirm).
    - `cash` / `pay_at_counter`: order is `confirmed` and sent to the kitchen immediately.
    """
    cart = await get_or_create_cart(db, owner_key(user, session_id))
    order, token, payment = await order_service.checkout(db, cart, user, data, background)
    return {"order": order_service.order_out(order), "order_access_token": token, "payment": payment}


@router.get("/me", response_model=Page[OrderOut])
async def my_orders(status: Optional[str] = None, page: int = Query(1, ge=1), size: int = Query(20, ge=1, le=100),
                    user=Depends(get_current_user), db=Depends(get_db)):
    query = {"user_id": user["_id"]}
    if status:
        query["status"] = status
    total = await db.orders.count_documents(query)
    docs = await db.orders.find(query).sort("created_at", -1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([order_service.order_out(d) for d in docs], total, page, size)


@router.get("/{order_id}", response_model=OrderOut)
async def get_order(order=Depends(get_order_for_viewer)):
    """Owner (JWT), staff/admin, or a guest with the `X-Order-Token` header."""
    return order_service.order_out(order)


@router.post("/{order_id}/cancel", response_model=OrderOut)
async def cancel_order(data: CancelIn, order=Depends(get_order_for_viewer), user=Depends(get_current_user_optional),
                       db=Depends(get_db)):
    """Customers can cancel only before the robot starts cooking."""
    if order["status"] not in ("pending_payment", "confirmed"):
        raise HTTPException(409, "This order can no longer be cancelled - please ask a staff member")
    started = await db.kitchen_jobs.find_one({"order_id": order["_id"], "status": {"$in": ["assigned", "cooking", "done"]}})
    if started:
        raise HTTPException(409, "The kitchen has already started this order")
    if order["payment"]["status"] == "paid":
        from app.services.payment_service import refund
        await refund(order)
        await db.orders.update_one({"_id": order["_id"]}, {"$set": {"payment.status": "refunded"}})
        order["payment"]["status"] = "refunded"
    updated = await order_service.change_status(db, order, "cancelled", user, data.reason or "Cancelled by customer")
    return order_service.order_out(updated)


@router.post("/{order_id}/reorder", response_model=ReorderOut)
async def reorder(order=Depends(get_order_for_viewer), user=Depends(get_current_user_optional),
                  session_id=Depends(get_session_id), db=Depends(get_db)):
    """Copies the order items back into the cart (skipping anything unavailable)."""
    cart = await get_or_create_cart(db, owner_key(user, session_id))
    added, skipped = 0, []
    for line in order["items"]:
        sels = [{"group_key": s["group_key"], "ingredient_id": s["ingredient_id"], "quantity": s["quantity"]}
                for s in line.get("selections", [])]
        try:
            await add_line(db, cart, line["menu_item_id"], line["quantity"], sels, line.get("special_instructions"))
            added += 1
        except HTTPException as exc:
            skipped.append(f"{line['name']}: {exc.detail}")
    await save_cart(db, cart)
    return {"added": added, "skipped": skipped}
