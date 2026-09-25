"""Application settings, loaded from environment variables / .env file."""
from functools import lru_cache
from typing import List, Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", case_sensitive=True)

    # --- App ---
    APP_NAME: str = "RoboKitchen Ordering System"
    APP_VERSION: str = "2.0.0"
    ENVIRONMENT: str = "development"  # development | staging | production
    DEBUG: bool = True
    ENABLE_DOCS: bool = True
    API_PREFIX: str = "/api/v1"

    # --- Security / JWT ---
    SECRET_KEY: str = "change-me-in-production-use-a-long-random-string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    EMAIL_VERIFY_EXPIRE_HOURS: int = 24
    PASSWORD_RESET_EXPIRE_MINUTES: int = 30
    REQUIRE_EMAIL_VERIFICATION: bool = False
    MAX_LOGIN_ATTEMPTS: int = 5
    LOCKOUT_MINUTES: int = 15
    RATE_LIMIT_ENABLED: bool = True

    # --- MongoDB ---
    # Use "mongomock://" to run with an in-memory database (demo/tests, needs mongomock-motor).
    MONGODB_URL: str = "mongodb://localhost:27017"
    MONGODB_DB_NAME: str = "robokitchen"
    MONGODB_MAX_POOL_SIZE: int = 100
    MONGODB_MIN_POOL_SIZE: int = 0

    # --- Redis (optional). Empty = in-memory fallbacks (single process only). ---
    REDIS_URL: Optional[str] = None

    # --- Email (SMTP). Empty SMTP_HOST = emails are printed to the log instead. ---
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_STARTTLS: bool = True
    SMTP_SSL: bool = False
    EMAIL_FROM: str = "noreply@robokitchen.com"
    EMAIL_FROM_NAME: str = "RoboKitchen"

    # --- Frontend / CORS ---
    FRONTEND_URL: str = "http://localhost:3000"
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:5173"

    # --- Payments ---
    PAYMENT_PROVIDER: str = "mock"  # mock | stripe
    STRIPE_SECRET_KEY: Optional[str] = None
    STRIPE_PUBLISHABLE_KEY: Optional[str] = None
    STRIPE_WEBHOOK_SECRET: Optional[str] = None
    CURRENCY: str = "usd"

    # --- Robot kitchen integration ---
    KITCHEN_API_KEY: str = "dev-kitchen-key-change-me"
    KITCHEN_WEBHOOK_URL: Optional[str] = None  # optional push notification to the robot controller

    # --- Default business settings (admins can change these at runtime via /admin/settings) ---
    TAX_RATE: float = 0.08
    SERVICE_FEE_CENTS: int = 0
    POINTS_PER_DOLLAR: int = 10
    POINT_VALUE_CENTS: int = 1  # 100 points = $1.00
    MIN_POINTS_TO_REDEEM: int = 100
    MAX_REDEEM_PERCENT: int = 50
    SILVER_THRESHOLD: int = 500
    GOLD_THRESHOLD: int = 2000
    PLATINUM_THRESHOLD: int = 5000

    # --- Misc ---
    CART_TTL_HOURS: int = 24
    SEED_ON_STARTUP: bool = False

    @property
    def cors_origins(self) -> List[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
