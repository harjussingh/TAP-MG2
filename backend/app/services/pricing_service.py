"""Server-side pricing. The client never sends prices - everything is recalculated here."""
from collections import defaultdict
from decimal import ROUND_HALF_UP, Decimal

from fastapi import HTTPException

from app.services.menu_service import load_ingredients


def _as_dict(sel) -> dict:
    return sel.model_dump() if hasattr(sel, "model_dump") else dict(sel)


async def price_line(db, menu_item_id: str, selections: list, quantity: int,
                     special_instructions: str | None = None) -> dict:
    item = await db.menu_items.find_one({"_id": menu_item_id, "is_deleted": {"$ne": True}})
    if not item:
        raise HTTPException(404, "Menu item not found")
    if not item.get("is_available", True):
        raise HTTPException(409, f"'{item['name']}' is currently unavailable")

    groups = {g["key"]: g for g in item.get("option_groups", [])}
    by_group: dict[str, list[dict]] = defaultdict(list)
    for raw in selections or []:
        s = _as_dict(raw)
        if s["group_key"] not in groups:
            raise HTTPException(422, f"Unknown option group '{s['group_key']}' for '{item['name']}'")
        by_group[s["group_key"]].append({"ingredient_id": s["ingredient_id"], "quantity": int(s.get("quantity", 1))})

    # Groups the customer did not touch fall back to their default options.
    for key, g in groups.items():
        if key not in by_group:
            defaults = [o for o in g.get("options", []) if o.get("is_default")]
            by_group[key] = [{"ingredient_id": o["ingredient_id"], "quantity": 1} for o in defaults]

    ingredients = await load_ingredients(db, [s["ingredient_id"] for sels in by_group.values() for s in sels])

    unit = item["base_price_cents"]
    calories = item.get("calories", 0)
    allergens = set(item.get("allergens", []))
    priced = []
    for key, g in groups.items():
        options = {o["ingredient_id"]: o for o in g.get("options", [])}
        chosen = by_group.get(key, [])
        total_qty = sum(s["quantity"] for s in chosen)
        if total_qty < g["min_select"]:
            raise HTTPException(422, f"Please choose at least {g['min_select']} option(s) for '{g['name']}'")
        if total_qty > g["max_select"]:
            raise HTTPException(422, f"You can choose at most {g['max_select']} option(s) for '{g['name']}'")
        seen = set()
        for s in chosen:
            ing_id = s["ingredient_id"]
            if ing_id not in options:
                raise HTTPException(422, f"Option not allowed in '{g['name']}'")
            if ing_id in seen:
                raise HTTPException(422, f"Duplicate option in '{g['name']}' - use quantity instead")
            seen.add(ing_id)
            ing = ingredients.get(ing_id)
            if not ing or ing.get("is_deleted"):
                raise HTTPException(422, f"Option no longer exists in '{g['name']}'")
            if not ing.get("is_available", True):
                raise HTTPException(409, f"'{ing['name']}' is out of stock")
            opt = options[ing_id]
            price = opt["price_cents"] if opt.get("price_cents") is not None else ing.get("price_cents", 0)
            unit += price * s["quantity"]
            calories += ing.get("calories", 0) * s["quantity"]
            allergens.update(ing.get("allergens", []))
            priced.append({
                "group_key": key, "group_name": g["name"], "ingredient_id": ing_id, "name": ing["name"],
                "quantity": s["quantity"], "price_cents": price, "dispenser_code": ing.get("dispenser_code"),
            })

    return {
        "menu_item_id": item["_id"],
        "name": item["name"],
        "image_url": item.get("image_url"),
        "item_type": item.get("item_type", "standard"),
        "quantity": quantity,
        "unit_price_cents": unit,
        "line_total_cents": unit * quantity,
        "selections": priced,
        "calories": calories,
        "allergens": sorted(allergens),
        "special_instructions": special_instructions,
        "prep_time_seconds": item.get("prep_time_seconds", 180),
    }


def _round(value: Decimal) -> int:
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def compute_totals(subtotal: int, cfg: dict, *, redeem_points: int = 0, available_points: int = 0,
                   tip_cents: int = 0) -> dict:
    discount = 0
    points_used = 0
    if redeem_points:
        if redeem_points < cfg["min_points_to_redeem"]:
            raise HTTPException(422, f"Minimum {cfg['min_points_to_redeem']} points to redeem")
        if redeem_points > available_points:
            raise HTTPException(422, "Not enough loyalty points")
        max_discount = subtotal * cfg["max_redeem_percent"] // 100
        points_used = min(redeem_points, max_discount // cfg["point_value_cents"])
        discount = points_used * cfg["point_value_cents"]
    taxable = subtotal - discount
    tax_rate = float(cfg["tax_rate"])
    tax = _round(Decimal(taxable) * Decimal(str(tax_rate)))
    fee = cfg["service_fee_cents"] if subtotal > 0 else 0
    return {
        "subtotal_cents": subtotal,
        "discount_cents": discount,
        "points_redeemed": points_used,
        "tax_rate": tax_rate,
        "tax_cents": tax,
        "service_fee_cents": fee,
        "tip_cents": tip_cents,
        "total_cents": taxable + tax + fee + tip_cents,
    }
