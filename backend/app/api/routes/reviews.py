from fastapi import APIRouter, Depends, Header, HTTPException, Query

from app.api.deps import can_view_order, get_current_user, get_current_user_optional
from app.core.database import get_db
from app.schemas.common import Page
from app.schemas.review import ItemReviewSummary, ReviewIn, ReviewOut
from app.utils.helpers import doc_out, new_id, page_response, utcnow

router = APIRouter(prefix="/reviews", tags=["Reviews"])


@router.post("", response_model=ReviewOut, status_code=201)
async def create_review(data: ReviewIn, x_order_token: str | None = Header(None),
                        user=Depends(get_current_user_optional), db=Depends(get_db)):
    """Post-order rating. Allowed once per order, after it is ready/completed."""
    order = await db.orders.find_one({"_id": data.order_id})
    if not order or not can_view_order(order, user, x_order_token) or (user and user["role"] != "customer"
                                                                        and order.get("user_id") != user["_id"]):
        raise HTTPException(404, "Order not found")
    if order["status"] not in ("ready", "completed"):
        raise HTTPException(409, "You can review an order once it is ready")
    if await db.reviews.find_one({"order_id": order["_id"]}):
        raise HTTPException(409, "This order has already been reviewed")
    order_items = {li["menu_item_id"] for li in order["items"]}
    item_ratings = [r.model_dump() for r in data.item_ratings if r.menu_item_id in order_items]
    review = {
        "_id": new_id("rev"), "order_id": order["_id"], "order_number": order["order_number"],
        "user_id": order.get("user_id"),
        "author_name": (order["customer"].get("name") or "Guest").split(" ")[0],
        "rating": data.rating, "comment": data.comment, "tags": data.tags[:10],
        "item_ratings": item_ratings, "item_ids": [r["menu_item_id"] for r in item_ratings],
        "is_visible": True, "staff_reply": None, "created_at": utcnow(),
    }
    await db.reviews.insert_one(review)
    for r in item_ratings:
        await db.menu_items.update_one({"_id": r["menu_item_id"]}, {"$inc": {"rating_sum": r["rating"], "rating_count": 1}})
    await db.orders.update_one({"_id": order["_id"]}, {"$set": {"has_review": True}})
    return doc_out(review)


@router.get("/me", response_model=list[ReviewOut])
async def my_reviews(user=Depends(get_current_user), db=Depends(get_db)):
    docs = await db.reviews.find({"user_id": user["_id"]}).sort("created_at", -1).to_list(200)
    return [doc_out(d) for d in docs]


@router.get("/menu-items/{menu_item_id}", response_model=Page[ReviewOut])
async def item_reviews(menu_item_id: str, page: int = Query(1, ge=1), size: int = Query(20, ge=1, le=100),
                       db=Depends(get_db)):
    query = {"item_ids": menu_item_id, "is_visible": True}
    total = await db.reviews.count_documents(query)
    docs = await db.reviews.find(query).sort("created_at", -1).skip((page - 1) * size).limit(size).to_list(size)
    return page_response([doc_out(d) for d in docs], total, page, size)


@router.get("/menu-items/{menu_item_id}/summary", response_model=ItemReviewSummary)
async def item_summary(menu_item_id: str, db=Depends(get_db)):
    item = await db.menu_items.find_one({"_id": menu_item_id})
    if not item:
        raise HTTPException(404, "Menu item not found")
    count = item.get("rating_count", 0)
    return {"menu_item_id": menu_item_id, "rating_count": count,
            "rating_avg": round(item.get("rating_sum", 0) / count, 2) if count else None}
