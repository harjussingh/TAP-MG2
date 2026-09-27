from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field

from app.models.enums import UserRole


class UserOut(BaseModel):
    id: str
    email: EmailStr | str
    full_name: str
    phone: Optional[str] = None
    role: UserRole
    email_verified: bool = False
    is_active: bool = True
    dietary_preferences: list[str] = []
    allergens: list[str] = []
    marketing_opt_in: bool = False
    loyalty_points: int = 0
    lifetime_points: int = 0
    loyalty_tier: str = "bronze"
    created_at: datetime
    last_login_at: Optional[datetime] = None


class UserUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=30)
    dietary_preferences: Optional[list[str]] = None
    allergens: Optional[list[str]] = None
    marketing_opt_in: Optional[bool] = None


class AdminUserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    full_name: str = Field(min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=30)
    role: UserRole = UserRole.staff


class AdminUserUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=30)
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None
