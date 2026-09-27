"""Simple fixed-window rate limiter. Uses Redis if available, otherwise process memory."""
import time

from fastapi import HTTPException, Request, status

from app.core.config import settings
from app.core.redis_client import get_redis

_memory: dict[str, list[float]] = {}


async def _hit(key: str, limit: int, window: int) -> bool:
    r = get_redis()
    if r is not None:
        k = f"rl:{key}"
        count = await r.incr(k)
        if count == 1:
            await r.expire(k, window)
        return count <= limit
    now = time.monotonic()
    bucket = [t for t in _memory.get(key, []) if now - t < window]
    bucket.append(now)
    _memory[key] = bucket
    return len(bucket) <= limit


def rate_limit(name: str, limit: int, window_seconds: int = 60):
    """Usage: @router.post(..., dependencies=[Depends(rate_limit("login", 10, 60))])"""

    async def dependency(request: Request) -> None:
        if not settings.RATE_LIMIT_ENABLED:
            return
        ip = request.headers.get("x-forwarded-for", "").split(",")[0].strip() or (
            request.client.host if request.client else "unknown"
        )
        if not await _hit(f"{name}:{ip}", limit, window_seconds):
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many requests, please try again later")

    return dependency
