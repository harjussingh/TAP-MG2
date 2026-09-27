from app.utils.helpers import new_id, utcnow


async def audit(db, actor: dict | None, action: str, entity: str, entity_id: str | None, details: dict | None = None):
    await db.audit_logs.insert_one({
        "_id": new_id("aud"),
        "actor_id": actor["_id"] if actor else None,
        "actor_email": actor.get("email") if actor else "system",
        "action": action,
        "entity": entity,
        "entity_id": entity_id,
        "details": details or {},
        "created_at": utcnow(),
    })
