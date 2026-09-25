"""Load demo data into the configured MongoDB.

    python -m scripts.seed_data           # only if the menu is empty
    python -m scripts.seed_data --reset   # WIPES all collections first
"""
import asyncio
import sys

from app.core.database import close_mongo, connect_to_mongo, get_db
from app.services.seed_service import DEMO_ADMIN, DEMO_CUSTOMER, DEMO_STAFF, seed_database


async def main(reset: bool) -> None:
    await connect_to_mongo()
    await seed_database(get_db(), force=reset)
    await close_mongo()
    print("Demo accounts:")
    for email, pw, _ in (DEMO_ADMIN, DEMO_STAFF, DEMO_CUSTOMER):
        print(f"  {email} / {pw}")


if __name__ == "__main__":
    asyncio.run(main("--reset" in sys.argv))
