from typing import Optional

from pydantic import BaseModel, EmailStr, Field, field_validator

from app.schemas.user import UserOut


def _check_strength(value: str) -> str:
    if len(value.encode("utf-8")) > 72:
        raise ValueError("Password is too long (max 72 bytes)")
    if not any(c.isalpha() for c in value) or not any(c.isdigit() for c in value):
        raise ValueError("Password must contain at least one letter and one number")
    return value


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    full_name: str = Field(min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=30)
    marketing_opt_in: bool = False

    _pw = field_validator("password")(_check_strength)


class LoginIn(BaseModel):
    email: EmailStr
    password: str = Field(max_length=128)


class TokenOut(BaseModel):
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_in: Optional[int] = None
    user: UserOut
    message: Optional[str] = None


class RefreshIn(BaseModel):
    refresh_token: str


class EmailIn(BaseModel):
    email: EmailStr


class TokenIn(BaseModel):
    token: str


class ResetPasswordIn(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=72)

    _pw = field_validator("new_password")(_check_strength)


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=72)

    _pw = field_validator("new_password")(_check_strength)
