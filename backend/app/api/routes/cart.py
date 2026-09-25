from fastapi import APIRouter, Depends, HTTPException, Query

from app.api.deps import get_current_user, get_current_user_optional, get_session_id
from app.core.database import get_db
from app.schemas.cart import CartContextIn, CartItemIn, CartItemUpdate, CartOut
from app.services.cart_service import add_line, cart_view, get_or_create_cart, owner_key, save_cart
from app.services.pricing_service import price_line

router = APIRouter(prefix="/cart", tags=["Cart"])


class CartCtx:
    def __init__(self, db, user, cart):
        self.db, self.user, self.cart = db, user, cart


async def cart_ctx(user=Depends(get_current_user_optional), session_id=Depends(get_session_id), db=Depends(get_db)):
    cart = await get_or_create_cart(db, owner_key(user, session_id))
    return CartCtx(db, user, cart)


def _find_line(cart: dict, line_id: str) -> dict:
    for line in cart["items"]:
        if line["line_id"] == line_id:
            return line
    raise HTTPException(404, "Cart item not found")


@router.get("", response_model=CartOut)
async def get_cart(redeem_points: int = Query(0, ge=0), tip_cents: int = Query(0, ge=0),
                   ctx: CartCtx = Depends(cart_ctx)):
    """Returns the cart with fresh prices. Pass redeem_points / tip_cents to preview checkout totals."""
    return await cart_view(ctx.db, ctx.cart, ctx.user, redeem_points, tip_cents)


@router.post("/items", response_model=CartOut, status_code=201)
async def add_item(data: CartItemIn, ctx: CartCtx = Depends(cart_ctx)):
    await add_line(ctx.db, ctx.cart, data.menu_item_id, data.quantity,
                   [s.model_dump() for s in data.selections], data.special_instructions)
    await save_cart(ctx.db, ctx.cart)
    return await cart_view(ctx.db, ctx.cart, ctx.user)


@router.patch("/items/{line_id}", response_model=CartOut)
async def update_item(line_id: str, data: CartItemUpdate, ctx: CartCtx = Depends(cart_ctx)):
    line = _find_line(ctx.cart, line_id)
    new = {**line, **{k: v for k, v in data.model_dump(exclude_unset=True).items()}}
    if data.selections is not None:
        new["selections"] = [s.model_dump() for s in data.selections]
    priced = await price_line(ctx.db, new["menu_item_id"], new["selections"], new["quantity"],
                              new.get("special_instructions"))
    new["selections"] = [{"group_key": s["group_key"], "ingredient_id": s["ingredient_id"], "quantity": s["quantity"]}
                         for s in priced["selections"]]
    new["unit_price_cents"] = priced["unit_price_cents"]
    line.update(new)
    await save_cart(ctx.db, ctx.cart)
    return await cart_view(ctx.db, ctx.cart, ctx.user)


@router.delete("/items/{line_id}", response_model=CartOut)
async def remove_item(line_id: str, ctx: CartCtx = Depends(cart_ctx)):
    _find_line(ctx.cart, line_id)
    ctx.cart["items"] = [li for li in ctx.cart["items"] if li["line_id"] != line_id]
    await save_cart(ctx.db, ctx.cart)
    return await cart_view(ctx.db, ctx.cart, ctx.user)


@router.delete("", response_model=CartOut)
async def clear_cart(ctx: CartCtx = Depends(cart_ctx)):
    ctx.cart["items"] = []
    await save_cart(ctx.db, ctx.cart)
    return await cart_view(ctx.db, ctx.cart, ctx.user)


@router.put("/context", response_model=CartOut)
async def set_context(data: CartContextIn, ctx: CartCtx = Depends(cart_ctx)):
    """Attach the scanned table (dine-in) or switch to takeaway."""
    if data.table_code:
        table = await ctx.db.tables.find_one({"code": data.table_code, "is_active": True})
        if not table:
            raise HTTPException(404, "Table not found")
        ctx.cart["table"] = {"id": table["_id"], "number": table["number"], "name": table.get("name")}
    else:
        ctx.cart["table"] = None
    ctx.cart["order_type"] = data.order_type.value
    await save_cart(ctx.db, ctx.cart)
    return await cart_view(ctx.db, ctx.cart, ctx.user)


@router.post("/merge", response_model=CartOut)
async def merge_guest_cart(user=Depends(get_current_user), session_id=Depends(get_session_id), db=Depends(get_db)):
    """Call right after login/register: moves the guest cart (X-Session-Id) into the user's cart."""
    user_cart = await get_or_create_cart(db, owner_key(user, None))
    if session_id:
        guest = await db.carts.find_one({"owner_key": f"session:{session_id}"})
        if guest:
            for line in guest["items"]:
                try:
                    await add_line(db, user_cart, line["menu_item_id"], line["quantity"], line["selections"],
                                   line.get("special_instructions"))
                except HTTPException:
                    continue
            if guest.get("table") and not user_cart.get("table"):
                user_cart["table"] = guest["table"]
                user_cart["order_type"] = guest.get("order_type", "dine_in")
            await db.carts.delete_one({"_id": guest["_id"]})
            await save_cart(db, user_cart)
    return await cart_view(db, user_cart, user)
