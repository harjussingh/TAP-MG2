"""Create (or promote) an admin user in production.

    python -m scripts.create_admin owner@restaurant.com "StrongPass123" "Owner Name"
"""
import asyncio
import sys

from app.api.routes.auth import new_user_doc
from app.core.database import close_mongo, connect_to_mongo, get_db


async def main(email: str, password: str, name: str) -> None:
    await connect_to_mongo()
    db = get_db()
    existing = await db.users.find_one({"email": email.lower()})
    if existing:
        await db.users.update_one({"_id": existing["_id"]}, {"$set": {"role": "admin", "is_active": True}})
        print(f"Promoted {email} to admin")
    else:
        await db.users.insert_one(new_user_doc(email, password, name, role="admin", email_verified=True))
        print(f"Created admin {email}")
    await close_mongo()


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    asyncio.run(main(*sys.argv[1:]))
