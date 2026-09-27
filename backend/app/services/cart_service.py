from datetime import timedelta

from fastapi import HTTPException

from app.core.config import settings
from app.services.pricing_service import compute_totals, price_line
from app.services.settings_service import get_app_settings
from app.utils.helpers import new_id, utcnow

MAX_LINES = 50


def owner_key(user: dict | None, session_id: str | None) -> str:
    if user:
        return f"user:{user['_id']}"
    if session_id:
        return f"session:{session_id}"
    raise HTTPException(400, "Log in or send an X-Session-Id header to use the cart")


async def get_or_create_cart(db, key: str) -> dict:
    cart = await db.carts.find_one({"owner_key": key})
    if cart:
        return cart
    now = utcnow()
    cart = {
        "_id": new_id("cart"), "owner_key": key, "items": [], "table": None, "order_type": "dine_in",
        "created_at": now, "updated_at": now, "expires_at": now + timedelta(hours=settings.CART_TTL_HOURS),
    }
    await db.carts.insert_one(cart)
    return cart


async def save_cart(db, cart: dict) -> None:
    now = utcnow()
    cart["updated_at"] = now
    cart["expires_at"] = now + timedelta(hours=settings.CART_TTL_HOURS)
    await db.carts.update_one({"_id": cart["_id"]}, {"$set": {
        "items": cart["items"], "table": cart.get("table"), "order_type": cart.get("order_type", "dine_in"),
        "updated_at": cart["updated_at"], "expires_at": cart["expires_at"],
    }})


def _signature(menu_item_id, selections, instructions) -> tuple:
    sels = sorted((s["group_key"], s["ingredient_id"], s.get("quantity", 1)) for s in selections)
    return menu_item_id, tuple(sels), (instructions or "").strip()


async def add_line(db, cart: dict, menu_item_id: str, quantity: int, selections: list[dict],
                   instructions: str | None) -> None:
    priced = await price_line(db, menu_item_id, selections, quantity, instructions)  # validates
    stored_sel = [{"group_key": s["group_key"], "ingredient_id": s["ingredient_id"], "quantity": s["quantity"]}
                  for s in priced["selections"]]
    sig = _signature(menu_item_id, stored_sel, instructions)
    for line in cart["items"]:
        if _signature(line["menu_item_id"], line["selections"], line.get("special_instructions")) == sig:
            line["quantity"] = min(20, line["quantity"] + quantity)
            return
    if len(cart["items"]) >= MAX_LINES:
        raise HTTPException(422, "Cart is full")
    cart["items"].append({
        "line_id": new_id("ln"), "menu_item_id": menu_item_id, "quantity": quantity, "selections": stored_sel,
        "special_instructions": instructions, "name": priced["name"], "unit_price_cents": priced["unit_price_cents"],
    })


async def price_cart(db, cart: dict) -> tuple[list[dict], int, bool]:
    lines, subtotal, has_errors = [], 0, False
    for line in cart["items"]:
        try:
            p = await price_line(db, line["menu_item_id"], line["selections"], line["quantity"],
                                 line.get("special_instructions"))
            p.update(line_id=line["line_id"], error=None)
            subtotal += p["line_total_cents"]
            lines.append(p)
        except HTTPException as exc:
            has_errors = True
            lines.append({
                "line_id": line["line_id"], "menu_item_id": line["menu_item_id"], "name": line.get("name", "Item"),
                "quantity": line["quantity"], "unit_price_cents": line.get("unit_price_cents", 0),
                "line_total_cents": 0, "selections": [], "special_instructions": line.get("special_instructions"),
                "error": exc.detail,
            })
    return lines, subtotal, has_errors


async def cart_view(db, cart: dict, user: dict | None, redeem_points: int = 0, tip_cents: int = 0) -> dict:
    lines, subtotal, has_errors = await price_cart(db, cart)
    cfg = await get_app_settings(db)
    totals = compute_totals(subtotal, cfg, redeem_points=redeem_points if user else 0,
                            available_points=(user or {}).get("loyalty_points", 0), tip_cents=tip_cents)
    return {
        "id": cart["_id"], "items": lines, "item_count": sum(li["quantity"] for li in lines),
        "table": cart.get("table"), "order_type": cart.get("order_type", "dine_in"),
        "totals": totals, "currency": cfg["currency"], "has_errors": has_errors,
    }
