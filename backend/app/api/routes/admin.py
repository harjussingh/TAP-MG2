"""Admin panel: dashboard, reports, users, orders, reviews, tables, settings, audit log."""
import csv
import io
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from fastapi.responses import StreamingResponse
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from app.api.deps import require_admin
from app.api.routes.auth import new_user_doc
from app.core.database import get_db
from app.schemas.admin import AppSettingsOut, AppSettingsUpdate
from app.schemas.common import Message, Page
from app.schemas.loyalty import LoyaltyAdjustIn
from app.schemas.order import CancelIn, OrderOut
from app.schemas.review import ReviewModerate, ReviewOut
from app.schemas.table import TableIn, TableOut, TableUpdate
from app.schemas.user import AdminUserCreate, AdminUserUpdate, UserOut
from app.services import loyalty_service, order_service
from app.services.audit_service import audit
from app.services.qr_service import qr_png, table_scan_url
from app.services.settings_service import get_app_settings, update_app_settings
from app.utils.helpers import doc_out, page_response, utcnow

router = APIRouter(prefix="/admin", tags=["Admin panel"])


def _range(date_from: Optional[datetime], date_to: Optional[datetime]) -> tuple[datetime, datetime]:
    end = date_to or utcnow()
    start = date_from or end.replace(hour=0, minute=0, second=0, microsecond=0)
    if start.tzinfo is None:
        start = start.replace(tzinfo=timezone.utc)
    if end.tzinfo is None:
        end = end.replace(tzinfo=timezone.utc)
    return start, end


# ---------------- Dashboard ----------------
@router.get("/dashboard")
async def dashboard(date_from: Optional[datetime] = None, date_to: Optional[datetime] = None,
                    admin=Depends(require_admin), db=Depends(get_db)):
    """KPIs for the admin home screen. Defaults to today (UTC). Dates are ISO-8601."""
    start, end = _range(date_from, date_to)
    period = {"created_at": {"$gte": start, "$lte": end}}
    orders = await db.orders.find(period, {"status": 1, "pricing": 1, "payment": 1, "items": 1, "created_at": 1,
                                           "order_type": 1}).to_list(None)
    valid = [o for o in orders if o["status"] != "cancelled"]
    paid = [o for o in valid if o["payment"]["status"] == "paid" or o["status"] == "completed"]
    revenue = sum(o["pricing"]["total_cents"] for o in paid)
    by_status: dict[str, int] = {}
    by_hour = [0] * 24
    items: dict[str, dict] = {}
    for o in orders:
        by_status[o["status"]] = by_status.get(o["status"], 0) + 1
    for o in valid:
        by_hour[o["created_at"].hour] += 1
        for li in o["items"]:
            it = items.setdefault(li["menu_item_id"], {"menu_item_id": li["menu_item_id"], "name": li["name"],
                                                       "quantity": 0, "revenue_cents": 0})
            it["quantity"] += li["quantity"]
            it["revenue_cents"] += li["line_total_cents"]
    reviews = await db.reviews.find(period, {"rating": 1}).to_list(None)
    return {
        "period": {"from": start, "to": end},
        "orders_total": len(orders),
        "orders_completed": by_status.get("completed", 0),
        "orders_cancelled": by_status.get("cancelled", 0),
        "revenue_cents": revenue,
        "tax_cents": sum(o["pricing"]["tax_cents"] for o in paid),
        "tips_cents": sum(o["pricing"]["tip_cents"] for o in paid),
        "average_order_cents": revenue // len(paid) if paid else 0,
        "orders_by_status": by_status,
        "orders_by_hour_utc": by_hour,
        "orders_by_type": {t: sum(1 for o in valid if o["order_type"] == t) for t in ("dine_in", "takeaway")},
        "top_items": sorted(items.values(), key=lambda x: x["quantity"], reverse=True)[:10],
        "reviews_count": len(reviews),
        "average_rating": round(sum(r["rating"] for r in reviews) / len(reviews), 2) if reviews else None,
        "new_customers": await db.users.count_documents({**period, "role": "customer"}),
        "active_orders": await db.orders.count_documents({"status": {"$in": ["confirmed", "preparing", "ready"]}}),
        "kitchen_failed_jobs": await db.kitchen_jobs.count_documents({"status": "failed"}),
    }


@router.get("/reports/orders.csv")
async def export_orders_csv(date_from: Optional[datetime] = None, date_to: Optional[datetime] = None,
                            admin=Depends(require_admin), db=Depends(get_db)):
    start, end = _range(date_from, date_to or utcnow())
    if not date_from:
        start = end - timedelta(days=30)
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["order_number", "created_at", "status", "type", "table", "customer", "items", "subtotal", "discount",
                "tax", "tip", "total", "payment_method", "payment_status"])
    async for o in db.orders.find({"created_at": {"$gte": start, "$lte": end}}).sort("created_at", 1):
        p = o["pricing"]
        w.writerow([o["order_number"], o["created_at"].isoformat(), o["status"], o["order_type"],
                    (o.get("table") or {}).get("number", ""), o["customer"].get("name") or "",
                    "; ".join(f"{li['quantity']}x {li['name']}" for li in o["items"]),
                    p["subtotal_cents"] / 100, p["discount_cents"] / 100, p["tax_cents"] / 100, p["tip_cents"] / 100,
                    p["total_cents"] / 100, o["payment"]["method"], o["payment"]["status"]])
    buf.seek(0)
    return StreamingResponse(iter([buf.getvalue()]), media_type="text/csv",
                             headers={"Content-Disposition": "attachment; filename=orders.csv"})


# ---------------- Users ----------------
@router.get("/users", response_model=Page[UserOut])
async def list_users(role: Optional[str] = None, search: Optional[str] = Query(None, max_length=80),
                     page: int = Query(1, ge=1), size: int = Query(20, ge=1, le=100),
                     admin=Depends(require_admin), db=Depends(get_db)):
    import re
    query: dict = {"is_deleted": {"$ne": True}}
    if role:
        query["role"] = role
    if search:
        rx = {"$regex": re.escape(search), "$options": "i"}
        query["$or"] = [{"email": rx}, {"full_name": rx}, {"phone": rx}]
    total = await db.users.count_documents(query)
    docs = await db.users.find(query).sort("created_at", -1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([doc_out(d) for d in docs], total, page, size)


@router.post("/users", response_model=UserOut, status_code=201)
async def create_user(data: AdminUserCreate, admin=Depends(require_admin), db=Depends(get_db)):
    """Create staff or admin accounts (customers normally self-register)."""
    user = new_user_doc(data.email, data.password, data.full_name, role=data.role.value, phone=data.phone,
                        email_verified=True)
    try:
        await db.users.insert_one(user)
    except DuplicateKeyError:
        raise HTTPException(409, "An account with this email already exists")
    await audit(db, admin, "user.create", "user", user["_id"], {"role": data.role.value})
    return doc_out(user)


@router.get("/users/{user_id}", response_model=UserOut)
async def get_user(user_id: str, admin=Depends(require_admin), db=Depends(get_db)):
    user = await db.users.find_one({"_id": user_id})
    if not user:
        raise HTTPException(404, "User not found")
    return doc_out(user)


@router.patch("/users/{user_id}", response_model=UserOut)
async def update_user(user_id: str, data: AdminUserUpdate, admin=Depends(require_admin), db=Depends(get_db)):
    changes = data.model_dump(mode="json", exclude_unset=True)
    if user_id == admin["_id"] and (changes.get("role") not in (None, "admin") or changes.get("is_active") is False):
        raise HTTPException(409, "You cannot demote or disable your own account")
    changes["updated_at"] = utcnow()
    user = await db.users.find_one_and_update({"_id": user_id}, {"$set": changes},
                                              return_document=ReturnDocument.AFTER)
    if not user:
        raise HTTPException(404, "User not found")
    if changes.get("is_active") is False or "role" in changes:
        await db.refresh_tokens.update_many({"user_id": user_id}, {"$set": {"revoked": True}})
    await audit(db, admin, "user.update", "user", user_id, {k: v for k, v in changes.items() if k != "updated_at"})
    return doc_out(user)


@router.post("/users/{user_id}/loyalty-adjust", response_model=UserOut)
async def adjust_points(user_id: str, data: LoyaltyAdjustIn, admin=Depends(require_admin), db=Depends(get_db)):
    if data.points == 0:
        raise HTTPException(422, "points must not be 0")
    user = await loyalty_service.adjust(db, user_id, data.points, f"Admin adjustment: {data.reason}")
    await audit(db, admin, "loyalty.adjust", "user", user_id, data.model_dump())
    return doc_out(user)


# ---------------- Orders ----------------
@router.get("/orders", response_model=Page[OrderOut])
async def list_orders(status: Optional[str] = None, payment_status: Optional[str] = None,
                      order_number: Optional[int] = None, user_id: Optional[str] = None,
                      date_from: Optional[datetime] = None, date_to: Optional[datetime] = None,
                      page: int = Query(1, ge=1), size: int = Query(20, ge=1, le=100),
                      admin=Depends(require_admin), db=Depends(get_db)):
    query: dict = {}
    if status:
        query["status"] = status
    if payment_status:
        query["payment.status"] = payment_status
    if order_number:
        query["order_number"] = order_number
    if user_id:
        query["user_id"] = user_id
    if date_from or date_to:
        query["created_at"] = {}
        if date_from:
            query["created_at"]["$gte"] = date_from
        if date_to:
            query["created_at"]["$lte"] = date_to
    total = await db.orders.count_documents(query)
    docs = await db.orders.find(query).sort("created_at", -1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([order_service.order_out(d) for d in docs], total, page, size)


@router.post("/orders/{order_id}/refund", response_model=OrderOut)
async def refund(order_id: str, data: CancelIn, admin=Depends(require_admin), db=Depends(get_db)):
    order = await db.orders.find_one({"_id": order_id})
    if not order:
        raise HTTPException(404, "Order not found")
    updated = await order_service.refund_order(db, order, admin, data.reason)
    await audit(db, admin, "order.refund", "order", order_id, {"reason": data.reason})
    return order_service.order_out(updated)


# ---------------- Reviews ----------------
@router.get("/reviews", response_model=Page[ReviewOut])
async def list_reviews(max_rating: Optional[int] = Query(None, ge=1, le=5), visible: Optional[bool] = None,
                       page: int = Query(1, ge=1), size: int = Query(20, ge=1, le=100),
                       admin=Depends(require_admin), db=Depends(get_db)):
    query: dict = {}
    if max_rating:
        query["rating"] = {"$lte": max_rating}
    if visible is not None:
        query["is_visible"] = visible
    total = await db.reviews.count_documents(query)
    docs = await db.reviews.find(query).sort("created_at", -1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([doc_out(d) for d in docs], total, page, size)


@router.patch("/reviews/{review_id}", response_model=ReviewOut)
async def moderate_review(review_id: str, data: ReviewModerate, admin=Depends(require_admin), db=Depends(get_db)):
    changes = data.model_dump(exclude_unset=True)
    review = await db.reviews.find_one_and_update({"_id": review_id}, {"$set": changes},
                                                  return_document=ReturnDocument.AFTER)
    if not review:
        raise HTTPException(404, "Review not found")
    await audit(db, admin, "review.moderate", "review", review_id, changes)
    return doc_out(review)


# ---------------- Tables & QR codes ----------------
def _table_out(t: dict) -> dict:
    return {**doc_out(t), "scan_url": table_scan_url(t["code"])}


@router.get("/tables", response_model=list[TableOut])
async def list_tables(admin=Depends(require_admin), db=Depends(get_db)):
    return [_table_out(t) for t in await db.tables.find().sort("number", 1).to_list(1000)]


@router.post("/tables", response_model=TableOut, status_code=201)
async def create_table(data: TableIn, admin=Depends(require_admin), db=Depends(get_db)):
    from app.utils.helpers import new_id
    t = {"_id": new_id("tbl"), **data.model_dump(), "name": data.name or f"Table {data.number}",
         "code": secrets.token_urlsafe(6), "created_at": utcnow(), "updated_at": utcnow()}
    try:
        await db.tables.insert_one(t)
    except DuplicateKeyError:
        raise HTTPException(409, "A table with this number already exists")
    await audit(db, admin, "table.create", "table", t["_id"])
    return _table_out(t)


@router.patch("/tables/{table_id}", response_model=TableOut)
async def update_table(table_id: str, data: TableUpdate, admin=Depends(require_admin), db=Depends(get_db)):
    try:
        t = await db.tables.find_one_and_update(
            {"_id": table_id}, {"$set": {**data.model_dump(exclude_unset=True), "updated_at": utcnow()}},
            return_document=ReturnDocument.AFTER)
    except DuplicateKeyError:
        raise HTTPException(409, "A table with this number already exists")
    if not t:
        raise HTTPException(404, "Table not found")
    return _table_out(t)


@router.post("/tables/{table_id}/regenerate-code", response_model=TableOut)
async def regenerate_code(table_id: str, admin=Depends(require_admin), db=Depends(get_db)):
    """Invalidates the old printed QR code (e.g. if a code was copied/abused)."""
    t = await db.tables.find_one_and_update({"_id": table_id}, {"$set": {"code": secrets.token_urlsafe(6)}},
                                            return_document=ReturnDocument.AFTER)
    if not t:
        raise HTTPException(404, "Table not found")
    await audit(db, admin, "table.regenerate_code", "table", table_id)
    return _table_out(t)


@router.get("/tables/{table_id}/qr.png", responses={200: {"content": {"image/png": {}}}})
async def table_qr(table_id: str, admin=Depends(require_admin), db=Depends(get_db)):
    t = await db.tables.find_one({"_id": table_id})
    if not t:
        raise HTTPException(404, "Table not found")
    return Response(qr_png(table_scan_url(t["code"])), media_type="image/png",
                    headers={"Content-Disposition": f"inline; filename=table-{t['number']}.png"})


@router.delete("/tables/{table_id}", response_model=Message)
async def delete_table(table_id: str, admin=Depends(require_admin), db=Depends(get_db)):
    res = await db.tables.delete_one({"_id": table_id})
    if not res.deleted_count:
        raise HTTPException(404, "Table not found")
    await audit(db, admin, "table.delete", "table", table_id)
    return {"message": "Table deleted"}


# ---------------- Settings ----------------
@router.get("/settings", response_model=AppSettingsOut)
async def get_settings(admin=Depends(require_admin), db=Depends(get_db)):
    return await get_app_settings(db)


@router.patch("/settings", response_model=AppSettingsOut)
async def patch_settings(data: AppSettingsUpdate, admin=Depends(require_admin), db=Depends(get_db)):
    changes = data.model_dump(exclude_unset=True)
    result = await update_app_settings(db, changes, admin["_id"])
    await audit(db, admin, "settings.update", "settings", "global", changes)
    return result


# ---------------- Audit log ----------------
@router.get("/audit-logs")
async def audit_logs(entity: Optional[str] = None, entity_id: Optional[str] = None,
                     page: int = Query(1, ge=1), size: int = Query(50, ge=1, le=200),
                     admin=Depends(require_admin), db=Depends(get_db)):
    query: dict = {}
    if entity:
        query["entity"] = entity
    if entity_id:
        query["entity_id"] = entity_id
    total = await db.audit_logs.count_documents(query)
    docs = await db.audit_logs.find(query).sort("created_at", -1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([doc_out(d) for d in docs], total, page, size)
