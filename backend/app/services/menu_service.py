from app.utils.helpers import doc_out


async def load_ingredients(db, ids) -> dict[str, dict]:
    ids = list(set(ids))
    if not ids:
        return {}
    return {d["_id"]: d async for d in db.ingredients.find({"_id": {"$in": ids}})}


def expand_item(item: dict, ingredients: dict[str, dict]) -> dict:
    out = doc_out(item)
    groups = []
    for g in item.get("option_groups", []):
        options = []
        for o in g.get("options", []):
            ing = ingredients.get(o["ingredient_id"])
            if not ing or ing.get("is_deleted"):
                continue
            options.append({
                "ingredient_id": ing["_id"],
                "name": ing["name"],
                "price_cents": o["price_cents"] if o.get("price_cents") is not None else ing.get("price_cents", 0),
                "calories": ing.get("calories", 0),
                "allergens": ing.get("allergens", []),
                "dietary_tags": ing.get("dietary_tags", []),
                "image_url": ing.get("image_url"),
                "is_default": o.get("is_default", False),
                "is_available": ing.get("is_available", True),
            })
        groups.append({**{k: g[k] for k in ("key", "name", "min_select", "max_select")}, "options": options})
    out["option_groups"] = groups
    count = item.get("rating_count", 0)
    out["rating_avg"] = round(item.get("rating_sum", 0) / count, 2) if count else None
    out["rating_count"] = count
    return out


async def expand_items(db, items: list[dict]) -> list[dict]:
    ids = [o["ingredient_id"] for it in items for g in it.get("option_groups", []) for o in g.get("options", [])]
    ingredients = await load_ingredients(db, ids)
    return [expand_item(it, ingredients) for it in items]
