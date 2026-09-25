"""One-time tokens for email verification and password reset (stored hashed, TTL-expired)."""
from datetime import timedelta

from fastapi import HTTPException

from app.core.security import generate_token, hash_token
from app.utils.helpers import utcnow


async def create_auth_token(db, user_id: str, token_type: str, ttl: timedelta) -> str:
    raw = generate_token()
    await db.auth_tokens.delete_many({"user_id": user_id, "type": token_type})
    await db.auth_tokens.insert_one({
        "_id": hash_token(raw),
        "user_id": user_id,
        "type": token_type,
        "created_at": utcnow(),
        "expires_at": utcnow() + ttl,
    })
    return raw


async def consume_auth_token(db, raw: str, token_type: str) -> str:
    doc = await db.auth_tokens.find_one_and_delete(
        {"_id": hash_token(raw), "type": token_type, "expires_at": {"$gt": utcnow()}}
    )
    if not doc:
        raise HTTPException(400, "This link is invalid or has expired")
    return doc["user_id"]
