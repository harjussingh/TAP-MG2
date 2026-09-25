"""Admin: categories, ingredients and menu items CRUD."""
from fastapi import APIRouter, Depends, HTTPException
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from app.api.deps import require_admin
from app.core.database import get_db
from app.schemas.common import Message
from app.schemas.menu import (CategoryIn, CategoryOut, CategoryUpdate, IngredientIn, IngredientOut, IngredientUpdate,
                              MenuItemIn, MenuItemOut, MenuItemUpdate)
from app.services.audit_service import audit
from app.services.menu_service import expand_items
from app.utils.helpers import doc_out, new_id, slugify, utcnow

router = APIRouter(prefix="/admin", tags=["Admin - menu"])


# ---------------- Categories ----------------
@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(admin=Depends(require_admin), db=Depends(get_db)):
    docs = await db.categories.find({"is_deleted": {"$ne": True}}).sort("sort_order", 1).to_list(500)
    return [doc_out(d) for d in docs]


@router.post("/categories", response_model=CategoryOut, status_code=201)
async def create_category(data: CategoryIn, admin=Depends(require_admin), db=Depends(get_db)):
    doc = {"_id": new_id("cat"), **data.model_dump(), "slug": data.slug or slugify(data.name),
           "created_at": utcnow(), "updated_at": utcnow()}
    try:
        await db.categories.insert_one(doc)
    except DuplicateKeyError:
        raise HTTPException(409, "A category with this slug already exists")
    await audit(db, admin, "category.create", "category", doc["_id"])
    return doc_out(doc)


@router.patch("/categories/{category_id}", response_model=CategoryOut)
async def update_category(category_id: str, data: CategoryUpdate, admin=Depends(require_admin), db=Depends(get_db)):
    changes = {**data.model_dump(exclude_unset=True), "updated_at": utcnow()}
    doc = await db.categories.find_one_and_update({"_id": category_id}, {"$set": changes}, return_document=ReturnDocument.AFTER)
    if not doc:
        raise HTTPException(404, "Category not found")
    await audit(db, admin, "category.update", "category", category_id, changes)
    return doc_out(doc)


@router.delete("/categories/{category_id}", response_model=Message)
async def delete_category(category_id: str, admin=Depends(require_admin), db=Depends(get_db)):
    if await db.menu_items.count_documents({"category_id": category_id, "is_deleted": {"$ne": True}}):
        raise HTTPException(409, "Move or delete the items in this category first")
    await db.categories.update_one({"_id": category_id}, {"$set": {"is_deleted": True, "is_active": False,
                                                                  "slug": f"deleted-{category_id}"}})
    await audit(db, admin, "category.delete", "category", category_id)
    return {"message": "Category deleted"}


# ---------------- Ingredients ----------------
@router.post("/ingredients", response_model=IngredientOut, status_code=201)
async def create_ingredient(data: IngredientIn, admin=Depends(require_admin), db=Depends(get_db)):
    doc = {"_id": new_id("ing"), **data.model_dump(), "is_deleted": False, "created_at": utcnow(), "updated_at": utcnow()}
    await db.ingredients.insert_one(doc)
    await audit(db, admin, "ingredient.create", "ingredient", doc["_id"])
    return doc_out(doc)


@router.patch("/ingredients/{ingredient_id}", response_model=IngredientOut)
async def update_ingredient(ingredient_id: str, data: IngredientUpdate, admin=Depends(require_admin),
                            db=Depends(get_db)):
    changes = {**data.model_dump(exclude_unset=True), "updated_at": utcnow()}
    doc = await db.ingredients.find_one_and_update({"_id": ingredient_id}, {"$set": changes}, return_document=ReturnDocument.AFTER)
    if not doc:
        raise HTTPException(404, "Ingredient not found")
    await audit(db, admin, "ingredient.update", "ingredient", ingredient_id, changes)
    return doc_out(doc)


@router.delete("/ingredients/{ingredient_id}", response_model=Message)
async def delete_ingredient(ingredient_id: str, admin=Depends(require_admin), db=Depends(get_db)):
    await db.ingredients.update_one({"_id": ingredient_id}, {"$set": {"is_deleted": True, "is_available": False}})
    await db.menu_items.update_many({}, {"$pull": {"option_groups.$[].options": {"ingredient_id": ingredient_id}}})
    await audit(db, admin, "ingredient.delete", "ingredient", ingredient_id)
    return {"message": "Ingredient deleted and removed from all menu items"}


# ---------------- Menu items ----------------
async def _validate_item(db, data) -> None:
    if getattr(data, "category_id", None) and not await db.categories.find_one({"_id": data.category_id}):
        raise HTTPException(422, "category_id does not exist")
    groups = getattr(data, "option_groups", None) or []
    ids = {o.ingredient_id for g in groups for o in g.options}
    if ids:
        found = await db.ingredients.count_documents({"_id": {"$in": list(ids)}, "is_deleted": {"$ne": True}})
        if found != len(ids):
            raise HTTPException(422, "One or more ingredient_id values do not exist")
    keys = [g.key for g in groups]
    if len(keys) != len(set(keys)):
        raise HTTPException(422, "Option group keys must be unique")


@router.get("/menu-items", response_model=list[MenuItemOut])
async def list_items(admin=Depends(require_admin), db=Depends(get_db)):
    docs = await db.menu_items.find({"is_deleted": {"$ne": True}}).sort([("sort_order", 1), ("name", 1)]).to_list(1000)
    return await expand_items(db, docs)


@router.post("/menu-items", response_model=MenuItemOut, status_code=201)
async def create_item(data: MenuItemIn, admin=Depends(require_admin), db=Depends(get_db)):
    await _validate_item(db, data)
    doc = {"_id": new_id("itm"), **data.model_dump(mode="json"), "slug": data.slug or slugify(data.name),
           "rating_sum": 0, "rating_count": 0, "is_deleted": False, "created_at": utcnow(), "updated_at": utcnow()}
    try:
        await db.menu_items.insert_one(doc)
    except DuplicateKeyError:
        raise HTTPException(409, "A menu item with this slug already exists")
    await audit(db, admin, "menu_item.create", "menu_item", doc["_id"])
    return (await expand_items(db, [doc]))[0]


@router.patch("/menu-items/{item_id}", response_model=MenuItemOut)
async def update_item(item_id: str, data: MenuItemUpdate, admin=Depends(require_admin), db=Depends(get_db)):
    await _validate_item(db, data)
    changes = {**data.model_dump(mode="json", exclude_unset=True), "updated_at": utcnow()}
    doc = await db.menu_items.find_one_and_update({"_id": item_id, "is_deleted": {"$ne": True}}, {"$set": changes},
                                                  return_document=ReturnDocument.AFTER)
    if not doc:
        raise HTTPException(404, "Menu item not found")
    await audit(db, admin, "menu_item.update", "menu_item", item_id, {"fields": list(changes)})
    return (await expand_items(db, [doc]))[0]


@router.delete("/menu-items/{item_id}", response_model=Message)
async def delete_item(item_id: str, admin=Depends(require_admin), db=Depends(get_db)):
    res = await db.menu_items.update_one({"_id": item_id}, {"$set": {
        "is_deleted": True, "is_available": False, "slug": f"deleted-{item_id}", "updated_at": utcnow()}})
    if not res.matched_count:
        raise HTTPException(404, "Menu item not found")
    await audit(db, admin, "menu_item.delete", "menu_item", item_id)
    return {"message": "Menu item deleted"}
