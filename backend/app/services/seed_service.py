"""Demo data: admin + staff accounts, categories, ingredients, menu items, tables."""
import logging
import secrets

from app.core.security import hash_password
from app.utils.helpers import new_id, slugify, utcnow

logger = logging.getLogger(__name__)

DEMO_ADMIN = ("admin@robokitchen.com", "Admin12345", "Admin User")
DEMO_STAFF = ("staff@robokitchen.com", "Staff12345", "Staff User")
DEMO_CUSTOMER = ("customer@robokitchen.com", "Customer123", "Demo Customer")

INGREDIENTS = [
    # name, group, price_cents, calories, allergens, dietary
    ("White Rice", "base", 0, 200, [], ["vegan", "gluten_free"]),
    ("Brown Rice", "base", 0, 215, [], ["vegan", "gluten_free"]),
    ("Quinoa", "base", 100, 180, [], ["vegan", "gluten_free"]),
    ("Mixed Greens", "base", 0, 20, [], ["vegan", "gluten_free"]),
    ("Udon Noodles", "base", 50, 250, ["gluten"], ["vegan"]),
    ("Grilled Chicken", "protein", 0, 180, [], ["gluten_free"]),
    ("Teriyaki Beef", "protein", 150, 240, ["soy", "gluten"], []),
    ("Crispy Tofu", "protein", 0, 150, ["soy"], ["vegan"]),
    ("Salmon", "protein", 250, 210, ["fish"], ["gluten_free"]),
    ("Soft Egg", "protein", 100, 70, ["egg"], ["vegetarian", "gluten_free"]),
    ("Sweet Corn", "veggies", 0, 60, [], ["vegan", "gluten_free"]),
    ("Edamame", "veggies", 0, 90, ["soy"], ["vegan", "gluten_free"]),
    ("Cucumber", "veggies", 0, 8, [], ["vegan", "gluten_free"]),
    ("Avocado", "veggies", 150, 120, [], ["vegan", "gluten_free"]),
    ("Carrot", "veggies", 0, 20, [], ["vegan", "gluten_free"]),
    ("Red Cabbage", "veggies", 0, 15, [], ["vegan", "gluten_free"]),
    ("Kimchi", "veggies", 50, 20, ["fish"], []),
    ("Teriyaki Sauce", "sauce", 0, 60, ["soy", "gluten"], ["vegan"]),
    ("Sriracha Mayo", "sauce", 0, 90, ["egg"], ["vegetarian"]),
    ("Sesame Ginger", "sauce", 0, 70, ["sesame", "soy"], ["vegan"]),
    ("Peanut Sauce", "sauce", 0, 110, ["peanut", "soy"], ["vegan"]),
    ("Sesame Seeds", "topping", 0, 50, ["sesame"], ["vegan", "gluten_free"]),
    ("Crispy Onions", "topping", 0, 60, ["gluten"], ["vegan"]),
    ("Nori Strips", "topping", 0, 5, [], ["vegan", "gluten_free"]),
    ("Spring Onion", "topping", 0, 5, [], ["vegan", "gluten_free"]),
]

CATEGORIES = [("Bowls", 1), ("Build Your Own", 0), ("Sides", 2), ("Drinks", 3)]


async def seed_database(db, force: bool = False) -> None:
    if not force and await db.menu_items.count_documents({}) > 0:
        logger.info("Seed skipped: menu already has data")
        return
    if force:
        for name in ["users", "categories", "ingredients", "menu_items", "tables", "orders", "kitchen_jobs",
                     "carts", "reviews", "saved_recipes", "loyalty_transactions", "counters", "refresh_tokens",
                     "auth_tokens", "audit_logs", "app_settings"]:
            await db[name].delete_many({})
    now = utcnow()

    for email, pw, name, role in [(*DEMO_ADMIN, "admin"), (*DEMO_STAFF, "staff"), (*DEMO_CUSTOMER, "customer")]:
        if not await db.users.find_one({"email": email}):
            await db.users.insert_one({
                "_id": new_id("usr"), "email": email, "password_hash": hash_password(pw), "full_name": name,
                "phone": None, "role": role, "email_verified": True, "is_active": True, "is_deleted": False,
                "dietary_preferences": [], "allergens": [], "marketing_opt_in": False,
                "loyalty_points": 250 if role == "customer" else 0, "lifetime_points": 250 if role == "customer" else 0,
                "loyalty_tier": "bronze", "failed_login_attempts": 0, "locked_until": None,
                "created_at": now, "updated_at": now, "last_login_at": None,
            })

    cats = {}
    for name, order in CATEGORIES:
        cid = new_id("cat")
        cats[name] = cid
        await db.categories.insert_one({"_id": cid, "name": name, "slug": slugify(name), "description": "",
                                        "image_url": None, "sort_order": order, "is_active": True,
                                        "created_at": now, "updated_at": now})

    ing = {}
    for i, (name, group, price, cal, allergens, dietary) in enumerate(INGREDIENTS, start=1):
        iid = new_id("ing")
        ing[name] = iid
        await db.ingredients.insert_one({
            "_id": iid, "name": name, "group": group, "price_cents": price, "calories": cal, "allergens": allergens,
            "dietary_tags": dietary, "image_url": None, "is_available": True, "is_deleted": False,
            "dispenser_code": f"D{i:02d}", "created_at": now, "updated_at": now,
        })

    def group(key, name, lo, hi, names, defaults=()):
        return {"key": key, "name": name, "min_select": lo, "max_select": hi,
                "options": [{"ingredient_id": ing[n], "price_cents": None, "is_default": n in defaults} for n in names]}

    by_group = {}
    for name, g, *_ in INGREDIENTS:
        by_group.setdefault(g, []).append(name)

    def item(name, cat, price, desc, *, item_type="standard", groups=(), tags=(), dietary=(), allergens=(),
             calories=0, featured=False, prep=180, order=0):
        return {"_id": new_id("itm"), "name": name, "slug": slugify(name), "description": desc,
                "category_id": cats[cat], "item_type": item_type, "base_price_cents": price, "image_url": None,
                "tags": list(tags), "dietary_tags": list(dietary), "allergens": list(allergens), "calories": calories,
                "prep_time_seconds": prep, "is_available": True, "is_featured": featured, "is_deleted": False,
                "sort_order": order, "option_groups": list(groups), "rating_sum": 0, "rating_count": 0,
                "created_at": now, "updated_at": now}

    items = [
        item("Build Your Own Bowl", "Build Your Own", 1095, "Pick a base, protein, veggies, sauce and toppings.",
             item_type="custom_bowl", featured=True, prep=240, tags=["custom"], groups=[
                 group("base", "Choose your base", 1, 2, by_group["base"]),
                 group("protein", "Choose your protein", 1, 2, by_group["protein"]),
                 group("veggies", "Add veggies", 0, 5, by_group["veggies"]),
                 group("sauce", "Pick a sauce", 1, 2, by_group["sauce"]),
                 group("topping", "Toppings", 0, 3, by_group["topping"]),
             ]),
        item("Teriyaki Chicken Bowl", "Bowls", 1295, "Grilled chicken, rice, edamame, corn and teriyaki glaze.",
             featured=True, tags=["bestseller"], order=1, groups=[
                 group("base", "Base", 1, 1, ["White Rice", "Brown Rice", "Quinoa"], ["White Rice"]),
                 group("extras", "Extras", 0, 3, ["Avocado", "Soft Egg", "Kimchi"]),
             ], calories=580, allergens=["soy", "gluten"]),
        item("Spicy Salmon Poke", "Bowls", 1595, "Salmon, cucumber, avocado and sriracha mayo.", order=2,
             tags=["spicy"], allergens=["fish", "egg"], calories=620, groups=[
                 group("base", "Base", 1, 1, ["White Rice", "Brown Rice", "Mixed Greens"], ["Brown Rice"]),
             ]),
        item("Tofu Power Bowl", "Bowls", 1195, "Crispy tofu, quinoa, greens and peanut sauce.", order=3,
             dietary=["vegan"], allergens=["soy", "peanut"], calories=540),
        item("Edamame", "Sides", 495, "Steamed edamame with sea salt.", dietary=["vegan", "gluten_free"],
             allergens=["soy"], calories=190, prep=60),
        item("Miso Soup", "Sides", 395, "Classic miso with tofu and seaweed.", allergens=["soy"], calories=80, prep=60),
        item("Iced Green Tea", "Drinks", 395, "Unsweetened cold-brewed green tea.", dietary=["vegan"], prep=30),
        item("Fresh Lemonade", "Drinks", 450, "House-made lemonade.", dietary=["vegan"], calories=120, prep=30),
    ]
    await db.menu_items.insert_many(items)

    for n in range(1, 11):
        await db.tables.insert_one({"_id": new_id("tbl"), "number": n, "name": f"Table {n}",
                                    "code": secrets.token_urlsafe(6), "seats": 4, "zone": "Main",
                                    "is_active": True, "created_at": now, "updated_at": now})
    logger.info("Seed complete: %d menu items, %d ingredients, 10 tables", len(items), len(INGREDIENTS))
