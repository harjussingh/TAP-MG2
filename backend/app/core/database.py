"""MongoDB connection and index management."""
import logging

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo import ASCENDING, DESCENDING, IndexModel

from app.core.config import settings

logger = logging.getLogger(__name__)


class _Mongo:
    client = None
    db: AsyncIOMotorDatabase | None = None
    is_mock: bool = False


mongo = _Mongo()


async def connect_to_mongo() -> None:
    if settings.MONGODB_URL.startswith("mongomock://"):
        from mongomock_motor import AsyncMongoMockClient

        mongo.client = AsyncMongoMockClient(tz_aware=True)
        mongo.is_mock = True
        logger.warning("Using in-memory mongomock database - data is NOT persisted")
    else:
        mongo.client = AsyncIOMotorClient(
            settings.MONGODB_URL,
            maxPoolSize=settings.MONGODB_MAX_POOL_SIZE,
            minPoolSize=settings.MONGODB_MIN_POOL_SIZE,
            serverSelectionTimeoutMS=10_000,
            tz_aware=True,
            retryWrites=True,
        )
        await mongo.client.admin.command("ping")
    mongo.db = mongo.client[settings.MONGODB_DB_NAME]
    await create_indexes(mongo.db)
    logger.info("MongoDB connected (db=%s)", settings.MONGODB_DB_NAME)


async def close_mongo() -> None:
    if mongo.client is not None:
        mongo.client.close()
        mongo.client = None
        mongo.db = None


def get_db() -> AsyncIOMotorDatabase:
    if mongo.db is None:
        raise RuntimeError("Database not initialised")
    return mongo.db


async def ping_db() -> bool:
    try:
        if mongo.is_mock:
            return mongo.db is not None
        await mongo.client.admin.command("ping")
        return True
    except Exception:  # noqa: BLE001
        return False


INDEXES: dict[str, list[IndexModel]] = {
    "users": [
        IndexModel([("email", ASCENDING)], unique=True),
        IndexModel([("role", ASCENDING)]),
        IndexModel([("created_at", DESCENDING)]),
    ],
    "refresh_tokens": [
        IndexModel([("user_id", ASCENDING)]),
        IndexModel([("expires_at", ASCENDING)], expireAfterSeconds=0),
    ],
    "auth_tokens": [
        IndexModel([("user_id", ASCENDING), ("type", ASCENDING)]),
        IndexModel([("expires_at", ASCENDING)], expireAfterSeconds=0),
    ],
    "tables": [
        IndexModel([("code", ASCENDING)], unique=True),
        IndexModel([("number", ASCENDING)], unique=True),
    ],
    "categories": [
        IndexModel([("slug", ASCENDING)], unique=True),
        IndexModel([("sort_order", ASCENDING)]),
    ],
    "ingredients": [IndexModel([("group", ASCENDING), ("is_available", ASCENDING)])],
    "menu_items": [
        IndexModel([("slug", ASCENDING)], unique=True),
        IndexModel([("category_id", ASCENDING), ("is_available", ASCENDING)]),
    ],
    "carts": [
        IndexModel([("owner_key", ASCENDING)], unique=True),
        IndexModel([("expires_at", ASCENDING)], expireAfterSeconds=0),
    ],
    "orders": [
        IndexModel([("order_number", ASCENDING)], unique=True),
        IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)]),
        IndexModel([("status", ASCENDING), ("created_at", ASCENDING)]),
        IndexModel([("created_at", DESCENDING)]),
        IndexModel([("payment.provider_ref", ASCENDING)]),
    ],
    "kitchen_jobs": [
        IndexModel([("status", ASCENDING), ("priority", DESCENDING), ("created_at", ASCENDING)]),
        IndexModel([("order_id", ASCENDING)]),
    ],
    "reviews": [
        IndexModel([("order_id", ASCENDING)], unique=True),
        IndexModel([("item_ids", ASCENDING), ("created_at", DESCENDING)]),
        IndexModel([("user_id", ASCENDING)]),
    ],
    "saved_recipes": [IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)])],
    "loyalty_transactions": [IndexModel([("user_id", ASCENDING), ("created_at", DESCENDING)])],
    "audit_logs": [
        IndexModel([("created_at", DESCENDING)]),
        IndexModel([("entity", ASCENDING), ("entity_id", ASCENDING)]),
    ],
}


async def create_indexes(db: AsyncIOMotorDatabase) -> None:
    for collection, indexes in INDEXES.items():
        try:
            await db[collection].create_indexes(indexes)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Could not create indexes for %s: %s", collection, exc)
