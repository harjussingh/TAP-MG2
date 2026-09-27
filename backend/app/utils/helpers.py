import math
import re
import uuid
from datetime import datetime, timezone

SENSITIVE_FIELDS = {"password_hash", "access_token_hash", "failed_login_attempts", "locked_until", "owner_key"}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def ensure_aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def new_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex}"


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def doc_out(doc: dict | None, exclude: set[str] | None = None) -> dict | None:
    """Convert a Mongo document to an API dict: _id -> id, drop sensitive fields."""
    if doc is None:
        return None
    d = dict(doc)
    d["id"] = d.pop("_id")
    for key in SENSITIVE_FIELDS | (exclude or set()):
        d.pop(key, None)
    return d


def page_response(items: list, total: int, page: int, size: int) -> dict:
    return {"items": items, "total": total, "page": page, "size": size, "pages": math.ceil(total / size) if size else 0}
