"""Staff panel: live order board, status changes, payments at counter, stock toggles."""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.deps import require_staff
from app.core.database import get_db
from app.core.websocket import ws_manager
from app.models.enums import ACTIVE_ORDER_STATUSES
from app.schemas.admin import KitchenJobStatusIn
from app.schemas.common import Page
from app.schemas.menu import AvailabilityIn, IngredientOut, MenuItemOut
from app.schemas.order import CancelIn, OrderOut, OrderStatusUpdate
from app.services import kitchen_service, order_service
from app.services.audit_service import audit
from app.services.menu_service import expand_items
from app.utils.helpers import doc_out, page_response, utcnow

router = APIRouter(prefix="/staff", tags=["Staff panel"])


async def _order(db, order_id):
    order = await db.orders.find_one({"_id": order_id})
    if not order:
        raise HTTPException(404, "Order not found")
    return order


@router.get("/orders", response_model=Page[OrderOut])
async def order_board(
    status: Optional[list[str]] = Query(None, description="Default: active orders (confirmed, preparing, ready)"),
    include_unpaid: bool = Query(True, description="Include card orders still waiting for payment"),
    table_number: Optional[int] = None,
    page: int = Query(1, ge=1), size: int = Query(50, ge=1, le=200),
    staff=Depends(require_staff), db=Depends(get_db),
):
    statuses = status or (ACTIVE_ORDER_STATUSES + (["pending_payment"] if include_unpaid else []))
    query: dict = {"status": {"$in": statuses}}
    if table_number is not None:
        query["table.number"] = table_number
    total = await db.orders.count_documents(query)
    docs = await db.orders.find(query).sort("created_at", 1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([order_service.order_out(d) for d in docs], total, page, size)


@router.get("/orders/summary")
async def board_summary(staff=Depends(require_staff), db=Depends(get_db)):
    """Counts per status for the board header."""
    counts = {}
    for s in ["pending_payment"] + ACTIVE_ORDER_STATUSES:
        counts[s] = await db.orders.count_documents({"status": s})
    counts["kitchen_queue"] = await db.kitchen_jobs.count_documents({"status": {"$in": kitchen_service.ACTIVE_JOB_STATUSES}})
    counts["kitchen_failed"] = await db.kitchen_jobs.count_documents({"status": "failed"})
    return counts


@router.get("/orders/{order_id}", response_model=OrderOut)
async def get_order(order_id: str, staff=Depends(require_staff), db=Depends(get_db)):
    return order_service.order_out(await _order(db, order_id))


@router.patch("/orders/{order_id}/status", response_model=OrderOut)
async def update_status(order_id: str, data: OrderStatusUpdate, staff=Depends(require_staff), db=Depends(get_db)):
    order = await _order(db, order_id)
    updated = await order_service.change_status(db, order, data.status.value, staff, data.note)
    await audit(db, staff, "order.status", "order", order_id, {"from": order["status"], "to": data.status.value})
    return order_service.order_out(updated)


@router.post("/orders/{order_id}/cancel", response_model=OrderOut)
async def cancel(order_id: str, data: CancelIn, staff=Depends(require_staff), db=Depends(get_db)):
    order = await _order(db, order_id)
    updated = await order_service.change_status(db, order, "cancelled", staff, data.reason or "Cancelled by staff")
    await audit(db, staff, "order.cancel", "order", order_id, {"reason": data.reason})
    return order_service.order_out(updated)


@router.post("/orders/{order_id}/mark-paid", response_model=OrderOut)
async def mark_paid(order_id: str, staff=Depends(require_staff), db=Depends(get_db)):
    """Cash / pay-at-counter received (or manual card confirmation)."""
    order = await _order(db, order_id)
    updated = await order_service.mark_paid(db, order, staff)
    await audit(db, staff, "order.mark_paid", "order", order_id)
    return order_service.order_out(updated)


@router.get("/kitchen/jobs")
async def kitchen_jobs(status: Optional[list[str]] = Query(None), staff=Depends(require_staff), db=Depends(get_db)):
    query = {"status": {"$in": status or ["queued", "assigned", "cooking", "failed"]}}
    docs = await db.kitchen_jobs.find(query).sort("created_at", 1).to_list(200)
    return [kitchen_service.job_out(d) for d in docs]


@router.post("/kitchen/jobs/{job_id}/retry")
async def retry_job(job_id: str, staff=Depends(require_staff), db=Depends(get_db)):
    job = await db.kitchen_jobs.find_one({"_id": job_id})
    if not job:
        raise HTTPException(404, "Job not found")
    job = await kitchen_service.set_job_status(db, job, "queued", "Re-queued by staff")
    await audit(db, staff, "kitchen.retry", "kitchen_job", job_id)
    return kitchen_service.job_out(job)


@router.post("/kitchen/jobs/{job_id}/status")
async def manual_job_status(job_id: str, data: KitchenJobStatusIn, staff=Depends(require_staff), db=Depends(get_db)):
    """Manual override when a staff member finishes an order by hand."""
    job = await db.kitchen_jobs.find_one({"_id": job_id})
    if not job:
        raise HTTPException(404, "Job not found")
    job = await kitchen_service.set_job_status(db, job, data.status, data.message, data.progress)
    return kitchen_service.job_out(job)


@router.get("/menu-items", response_model=list[MenuItemOut])
async def all_items(staff=Depends(require_staff), db=Depends(get_db)):
    docs = await db.menu_items.find({"is_deleted": {"$ne": True}}).sort("name", 1).to_list(1000)
    return await expand_items(db, docs)


@router.patch("/menu-items/{item_id}/availability", response_model=dict)
async def item_availability(item_id: str, data: AvailabilityIn, staff=Depends(require_staff), db=Depends(get_db)):
    res = await db.menu_items.update_one({"_id": item_id}, {"$set": {"is_available": data.is_available, "updated_at": utcnow()}})
    if not res.matched_count:
        raise HTTPException(404, "Menu item not found")
    await ws_manager.publish("staff", "menu.availability", {"menu_item_id": item_id, "is_available": data.is_available})
    await audit(db, staff, "menu_item.availability", "menu_item", item_id, data.model_dump())
    return {"id": item_id, "is_available": data.is_available}


@router.get("/ingredients", response_model=list[IngredientOut])
async def ingredients(staff=Depends(require_staff), db=Depends(get_db)):
    docs = await db.ingredients.find({"is_deleted": {"$ne": True}}).sort([("group", 1), ("name", 1)]).to_list(1000)
    return [doc_out(d) for d in docs]


@router.patch("/ingredients/{ingredient_id}/availability")
async def ingredient_availability(ingredient_id: str, data: AvailabilityIn, staff=Depends(require_staff),
                                  db=Depends(get_db)):
    """Mark an ingredient sold out: every bowl option using it becomes unavailable instantly."""
    res = await db.ingredients.update_one({"_id": ingredient_id},
                                          {"$set": {"is_available": data.is_available, "updated_at": utcnow()}})
    if not res.matched_count:
        raise HTTPException(404, "Ingredient not found")
    await ws_manager.publish("staff", "ingredient.availability",
                             {"ingredient_id": ingredient_id, "is_available": data.is_available})
    await audit(db, staff, "ingredient.availability", "ingredient", ingredient_id, data.model_dump())
    return {"id": ingredient_id, "is_available": data.is_available}
