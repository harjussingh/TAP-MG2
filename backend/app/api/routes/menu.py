import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.core.database import get_db
from app.schemas.common import Page
from app.schemas.menu import CategoryOut, IngredientOut, MenuItemOut, PricedLine, PriceQuoteIn
from app.services.menu_service import expand_item, expand_items, load_ingredients
from app.services.pricing_service import price_line
from app.utils.helpers import doc_out, page_response

router = APIRouter(prefix="/menu", tags=["Menu"])


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(db=Depends(get_db)):
    docs = await db.categories.find({"is_active": True, "is_deleted": {"$ne": True}}).sort("sort_order", 1).to_list(200)
    return [doc_out(d) for d in docs]


@router.get("/items", response_model=Page[MenuItemOut])
async def list_items(
    category_id: Optional[str] = None,
    category_slug: Optional[str] = None,
    search: Optional[str] = Query(None, max_length=80),
    tags: list[str] = Query([], description="All tags must match, e.g. ?tags=spicy"),
    dietary: list[str] = Query([], description="e.g. ?dietary=vegan&dietary=gluten_free"),
    exclude_allergens: list[str] = Query([], description="Hide items containing these allergens"),
    item_type: Optional[str] = None,
    featured: Optional[bool] = None,
    include_unavailable: bool = False,
    page: int = Query(1, ge=1),
    size: int = Query(50, ge=1, le=100),
    db=Depends(get_db),
):
    query: dict = {"is_deleted": {"$ne": True}}
    if not include_unavailable:
        query["is_available"] = True
    if category_slug and not category_id:
        cat = await db.categories.find_one({"slug": category_slug})
        if not cat:
            return page_response([], 0, page, size)
        category_id = cat["_id"]
    if category_id:
        query["category_id"] = category_id
    if search:
        rx = {"$regex": re.escape(search), "$options": "i"}
        query["$or"] = [{"name": rx}, {"description": rx}, {"tags": rx}]
    if tags:
        query["tags"] = {"$all": tags}
    if dietary:
        query["dietary_tags"] = {"$all": dietary}
    if exclude_allergens:
        query["allergens"] = {"$nin": exclude_allergens}
    if item_type:
        query["item_type"] = item_type
    if featured is not None:
        query["is_featured"] = featured
    total = await db.menu_items.count_documents(query)
    docs = await db.menu_items.find(query).sort([("sort_order", 1), ("name", 1)]).skip((page - 1) * size).limit(size).to_list(size)
    return page_response(await expand_items(db, docs), total, page, size)


@router.get("/items/{id_or_slug}", response_model=MenuItemOut)
async def get_item(id_or_slug: str, db=Depends(get_db)):
    item = await db.menu_items.find_one({"$or": [{"_id": id_or_slug}, {"slug": id_or_slug}], "is_deleted": {"$ne": True}})
    if not item:
        raise HTTPException(404, "Menu item not found")
    ids = [o["ingredient_id"] for g in item.get("option_groups", []) for o in g.get("options", [])]
    return expand_item(item, await load_ingredients(db, ids))


@router.get("/ingredients", response_model=list[IngredientOut])
async def list_ingredients(group: Optional[str] = None, db=Depends(get_db)):
    query: dict = {"is_deleted": {"$ne": True}}
    if group:
        query["group"] = group
    docs = await db.ingredients.find(query).sort([("group", 1), ("name", 1)]).to_list(1000)
    return [doc_out(d) for d in docs]


@router.post("/price-quote", response_model=PricedLine)
async def price_quote(data: PriceQuoteIn, db=Depends(get_db)):
    """Live price, calories and allergens for the bowl builder as the customer picks options."""
    return await price_line(db, data.menu_item_id, data.selections, data.quantity)
