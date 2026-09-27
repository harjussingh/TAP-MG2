"""RoboKitchen backend - application entry point."""
import logging
import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import (admin, admin_menu, auth, cart, kitchen, loyalty, menu, orders, payments, recipes,
                            reviews, staff, tables, users, ws)
from app.core.config import settings
from app.core.database import close_mongo, connect_to_mongo, get_db, ping_db
from app.core.redis_client import close_redis, connect_redis, get_redis
from app.core.websocket import ws_manager

logging.basicConfig(level=logging.DEBUG if settings.DEBUG else logging.INFO,
                    format="%(asctime)s %(levelname)s %(name)s - %(message)s")
logging.getLogger("pymongo").setLevel(logging.WARNING)
logger = logging.getLogger("robokitchen")


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.is_production and settings.SECRET_KEY.startswith("change-me"):
        raise RuntimeError("Set a real SECRET_KEY before running in production")
    await connect_to_mongo()
    await connect_redis()
    await ws_manager.start()
    if settings.SEED_ON_STARTUP:
        from app.services.seed_service import seed_database
        await seed_database(get_db())
    logger.info("%s v%s started (%s)", settings.APP_NAME, settings.APP_VERSION, settings.ENVIRONMENT)
    yield
    await ws_manager.stop()
    await close_redis()
    await close_mongo()


P = settings.API_PREFIX
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Backend for the RoboKitchen QR ordering app, staff panel, admin panel and robot kitchen.",
    lifespan=lifespan,
    docs_url=f"{P}/docs" if settings.ENABLE_DOCS else None,
    redoc_url=f"{P}/redoc" if settings.ENABLE_DOCS else None,
    openapi_url=f"{P}/openapi.json" if settings.ENABLE_DOCS else None,
)

app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"], expose_headers=["X-Request-ID", "X-Process-Time"])
app.add_middleware(GZipMiddleware, minimum_size=1000)


@app.middleware("http")
async def request_context(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or uuid.uuid4().hex[:12]
    start = time.perf_counter()
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time"] = f"{time.perf_counter() - start:.4f}"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response


@app.exception_handler(Exception)
async def unhandled_error(request: Request, exc: Exception):
    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(status_code=500, content={"detail": str(exc) if settings.DEBUG else "Internal server error"})


for r in (auth, users, tables, menu, cart, orders, payments, reviews, recipes, loyalty, staff, kitchen,
          admin_menu, admin, ws):
    app.include_router(r.router, prefix=P)


@app.get("/", tags=["Health"])
async def root():
    return {"name": settings.APP_NAME, "version": settings.APP_VERSION, "docs": f"{P}/docs"}


@app.get("/health", tags=["Health"])
async def health():
    db_ok = await ping_db()
    redis = get_redis()
    redis_state = "disabled"
    if redis is not None:
        try:
            await redis.ping()
            redis_state = "ok"
        except Exception:  # noqa: BLE001
            redis_state = "error"
    return JSONResponse(status_code=200 if db_ok else 503, content={
        "status": "ok" if db_ok else "degraded", "database": "ok" if db_ok else "error", "redis": redis_state,
        "version": settings.APP_VERSION, "environment": settings.ENVIRONMENT})
