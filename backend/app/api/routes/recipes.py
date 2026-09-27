from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_current_user
from app.core.database import get_db
from app.schemas.cart import CartOut
from app.schemas.common import Message
from app.schemas.recipe import RecipeIn, RecipeOut, RecipeUpdate
from app.services.cart_service import add_line, cart_view, get_or_create_cart, owner_key, save_cart
from app.services.pricing_service import price_line
from app.utils.helpers import new_id, utcnow

router = APIRouter(prefix="/recipes", tags=["Saved recipes"])
MAX_RECIPES = 50


def _stored(priced: dict) -> list[dict]:
    return [{"group_key": s["group_key"], "ingredient_id": s["ingredient_id"], "quantity": s["quantity"]}
            for s in priced["selections"]]


async def _recipe_out(db, r: dict) -> dict:
    out = {"id": r["_id"], "name": r["name"], "menu_item_id": r["menu_item_id"],
           "menu_item_name": r.get("menu_item_name", ""), "special_instructions": r.get("special_instructions"),
           "times_ordered": r.get("times_ordered", 0), "created_at": r["created_at"]}
    try:
        p = await price_line(db, r["menu_item_id"], r["selections"], 1, r.get("special_instructions"))
        out.update(selections=p["selections"], current_price_cents=p["unit_price_cents"], calories=p["calories"],
                   is_available=True, unavailable_reason=None)
    except HTTPException as exc:
        out.update(selections=[], current_price_cents=None, calories=None, is_available=False,
                   unavailable_reason=exc.detail)
    return out


async def _get(db, recipe_id, user):
    r = await db.saved_recipes.find_one({"_id": recipe_id, "user_id": user["_id"]})
    if not r:
        raise HTTPException(404, "Recipe not found")
    return r


@router.post("", response_model=RecipeOut, status_code=201)
async def save_recipe(data: RecipeIn, user=Depends(get_current_user), db=Depends(get_db)):
    """Save a custom bowl configuration for one-tap reordering."""
    if await db.saved_recipes.count_documents({"user_id": user["_id"]}) >= MAX_RECIPES:
        raise HTTPException(422, f"You can save up to {MAX_RECIPES} recipes")
    priced = await price_line(db, data.menu_item_id, data.selections, 1, data.special_instructions)
    r = {"_id": new_id("rcp"), "user_id": user["_id"], "name": data.name.strip(), "menu_item_id": data.menu_item_id,
         "menu_item_name": priced["name"], "selections": _stored(priced),
         "special_instructions": data.special_instructions, "times_ordered": 0,
         "created_at": utcnow(), "updated_at": utcnow()}
    await db.saved_recipes.insert_one(r)
    return await _recipe_out(db, r)


@router.get("", response_model=list[RecipeOut])
async def list_recipes(user=Depends(get_current_user), db=Depends(get_db)):
    docs = await db.saved_recipes.find({"user_id": user["_id"]}).sort("created_at", -1).to_list(MAX_RECIPES)
    return [await _recipe_out(db, r) for r in docs]


@router.get("/{recipe_id}", response_model=RecipeOut)
async def get_recipe(recipe_id: str, user=Depends(get_current_user), db=Depends(get_db)):
    return await _recipe_out(db, await _get(db, recipe_id, user))


@router.patch("/{recipe_id}", response_model=RecipeOut)
async def update_recipe(recipe_id: str, data: RecipeUpdate, user=Depends(get_current_user), db=Depends(get_db)):
    r = await _get(db, recipe_id, user)
    changes = data.model_dump(exclude_unset=True)
    if "selections" in changes or "special_instructions" in changes:
        sels = [s.model_dump() for s in data.selections] if data.selections is not None else r["selections"]
        priced = await price_line(db, r["menu_item_id"], sels, 1, changes.get("special_instructions"))
        changes["selections"] = _stored(priced)
    if "name" in changes:
        changes["name"] = changes["name"].strip()
    changes["updated_at"] = utcnow()
    await db.saved_recipes.update_one({"_id": r["_id"]}, {"$set": changes})
    r.update(changes)
    return await _recipe_out(db, r)


@router.delete("/{recipe_id}", response_model=Message)
async def delete_recipe(recipe_id: str, user=Depends(get_current_user), db=Depends(get_db)):
    await _get(db, recipe_id, user)
    await db.saved_recipes.delete_one({"_id": recipe_id})
    return {"message": "Recipe deleted"}


@router.post("/{recipe_id}/add-to-cart", response_model=CartOut)
async def add_recipe_to_cart(recipe_id: str, quantity: int = 1, user=Depends(get_current_user), db=Depends(get_db)):
    r = await _get(db, recipe_id, user)
    cart = await get_or_create_cart(db, owner_key(user, None))
    await add_line(db, cart, r["menu_item_id"], max(1, min(quantity, 20)), r["selections"],
                   r.get("special_instructions"))
    await save_cart(db, cart)
    await db.saved_recipes.update_one({"_id": r["_id"]}, {"$inc": {"times_ordered": 1}})
    return await cart_view(db, cart, user)
