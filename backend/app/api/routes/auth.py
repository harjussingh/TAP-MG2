from datetime import timedelta

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from pymongo.errors import DuplicateKeyError

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import rate_limit
from app.core.security import create_access_token, create_refresh_token, decode_token, hash_password, verify_password
from app.schemas.auth import EmailIn, LoginIn, RefreshIn, RegisterIn, ResetPasswordIn, TokenIn, TokenOut
from app.schemas.common import Message
from app.schemas.user import UserOut
from app.services.auth_token_service import consume_auth_token, create_auth_token
from app.services.email_service import send_password_reset_email, send_verification_email
from app.utils.helpers import doc_out, ensure_aware, new_id, utcnow

router = APIRouter(prefix="/auth", tags=["Auth"])


def new_user_doc(email: str, password: str, full_name: str, role: str = "customer", phone: str | None = None,
                 marketing_opt_in: bool = False, email_verified: bool = False) -> dict:
    now = utcnow()
    return {
        "_id": new_id("usr"), "email": email.lower(), "password_hash": hash_password(password),
        "full_name": full_name.strip(), "phone": phone, "role": role, "email_verified": email_verified,
        "is_active": True, "is_deleted": False, "dietary_preferences": [], "allergens": [],
        "marketing_opt_in": marketing_opt_in, "loyalty_points": 0, "lifetime_points": 0, "loyalty_tier": "bronze",
        "failed_login_attempts": 0, "locked_until": None, "created_at": now, "updated_at": now, "last_login_at": None,
    }


async def issue_tokens(db, user: dict, request: Request) -> dict:
    refresh, jti, expires = create_refresh_token(user["_id"])
    await db.refresh_tokens.insert_one({
        "_id": jti, "user_id": user["_id"], "revoked": False, "created_at": utcnow(), "expires_at": expires,
        "user_agent": (request.headers.get("user-agent") or "")[:200],
    })
    return {
        "access_token": create_access_token(user["_id"], user["role"]), "refresh_token": refresh,
        "token_type": "bearer", "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60, "user": doc_out(user),
    }


@router.post("/register", response_model=TokenOut, status_code=201,
             dependencies=[Depends(rate_limit("register", 10, 3600))])
async def register(data: RegisterIn, request: Request, background: BackgroundTasks, db=Depends(get_db)):
    """Create a customer account and send a verification email."""
    user = new_user_doc(data.email, data.password, data.full_name, phone=data.phone,
                        marketing_opt_in=data.marketing_opt_in)
    try:
        await db.users.insert_one(user)
    except DuplicateKeyError:
        raise HTTPException(409, "An account with this email already exists")
    token = await create_auth_token(db, user["_id"], "verify_email", timedelta(hours=settings.EMAIL_VERIFY_EXPIRE_HOURS))
    background.add_task(send_verification_email, user["email"], user["full_name"], token)
    if settings.REQUIRE_EMAIL_VERIFICATION:
        return {"user": doc_out(user), "message": "Check your email to verify your account, then log in."}
    return {**await issue_tokens(db, user, request), "message": "Account created. Please verify your email."}


@router.post("/login", response_model=TokenOut, dependencies=[Depends(rate_limit("login", 20, 60))])
async def login(data: LoginIn, request: Request, db=Depends(get_db)):
    user = await db.users.find_one({"email": data.email.lower(), "is_deleted": {"$ne": True}})
    now = utcnow()
    if user and user.get("locked_until") and ensure_aware(user["locked_until"]) > now:
        raise HTTPException(423, "Too many failed attempts. Try again later or reset your password.")
    if not user or not verify_password(data.password, user.get("password_hash")):
        if user:
            attempts = user.get("failed_login_attempts", 0) + 1
            upd = {"failed_login_attempts": attempts}
            if attempts >= settings.MAX_LOGIN_ATTEMPTS:
                upd = {"failed_login_attempts": 0, "locked_until": now + timedelta(minutes=settings.LOCKOUT_MINUTES)}
            await db.users.update_one({"_id": user["_id"]}, {"$set": upd})
        raise HTTPException(401, "Invalid email or password")
    if not user.get("is_active", True):
        raise HTTPException(403, "This account has been disabled")
    if settings.REQUIRE_EMAIL_VERIFICATION and not user.get("email_verified"):
        raise HTTPException(403, "Please verify your email before logging in")
    await db.users.update_one({"_id": user["_id"]},
                              {"$set": {"failed_login_attempts": 0, "locked_until": None, "last_login_at": now}})
    user["last_login_at"] = now
    return await issue_tokens(db, user, request)


@router.post("/refresh", response_model=TokenOut)
async def refresh(data: RefreshIn, request: Request, db=Depends(get_db)):
    """Exchange a refresh token for a new access + refresh token pair (rotation)."""
    payload = decode_token(data.refresh_token, "refresh")
    doc = await db.refresh_tokens.find_one_and_update(
        {"_id": payload["jti"], "revoked": False}, {"$set": {"revoked": True, "revoked_at": utcnow()}})
    if not doc:
        # Token reuse -> possible theft: revoke every session of this user.
        await db.refresh_tokens.update_many({"user_id": payload["sub"]}, {"$set": {"revoked": True}})
        raise HTTPException(401, "Refresh token is no longer valid, please log in again")
    user = await db.users.find_one({"_id": payload["sub"], "is_deleted": {"$ne": True}})
    if not user or not user.get("is_active", True):
        raise HTTPException(401, "User not found or disabled")
    return await issue_tokens(db, user, request)


@router.post("/logout", response_model=Message)
async def logout(data: RefreshIn, db=Depends(get_db)):
    try:
        payload = decode_token(data.refresh_token, "refresh")
        await db.refresh_tokens.update_one({"_id": payload["jti"]}, {"$set": {"revoked": True}})
    except HTTPException:
        pass
    return {"message": "Logged out"}


@router.post("/logout-all", response_model=Message)
async def logout_all(user=Depends(get_current_user), db=Depends(get_db)):
    await db.refresh_tokens.update_many({"user_id": user["_id"]}, {"$set": {"revoked": True}})
    return {"message": "Logged out from all devices"}


@router.post("/verify-email", response_model=Message)
async def verify_email(data: TokenIn, db=Depends(get_db)):
    user_id = await consume_auth_token(db, data.token, "verify_email")
    await db.users.update_one({"_id": user_id}, {"$set": {"email_verified": True, "updated_at": utcnow()}})
    return {"message": "Email verified"}


@router.post("/resend-verification", response_model=Message,
             dependencies=[Depends(rate_limit("resend", 5, 3600))])
async def resend_verification(data: EmailIn, background: BackgroundTasks, db=Depends(get_db)):
    user = await db.users.find_one({"email": data.email.lower(), "is_deleted": {"$ne": True}})
    if user and not user.get("email_verified"):
        token = await create_auth_token(db, user["_id"], "verify_email",
                                        timedelta(hours=settings.EMAIL_VERIFY_EXPIRE_HOURS))
        background.add_task(send_verification_email, user["email"], user["full_name"], token)
    return {"message": "If the account exists and is unverified, a new email has been sent"}


@router.post("/forgot-password", response_model=Message,
             dependencies=[Depends(rate_limit("forgot", 5, 3600))])
async def forgot_password(data: EmailIn, background: BackgroundTasks, db=Depends(get_db)):
    user = await db.users.find_one({"email": data.email.lower(), "is_deleted": {"$ne": True}})
    if user:
        token = await create_auth_token(db, user["_id"], "reset_password",
                                        timedelta(minutes=settings.PASSWORD_RESET_EXPIRE_MINUTES))
        background.add_task(send_password_reset_email, user["email"], user["full_name"], token)
    return {"message": "If an account exists for this email, a reset link has been sent"}


@router.post("/reset-password", response_model=Message)
async def reset_password(data: ResetPasswordIn, db=Depends(get_db)):
    user_id = await consume_auth_token(db, data.token, "reset_password")
    await db.users.update_one({"_id": user_id}, {"$set": {
        "password_hash": hash_password(data.new_password), "failed_login_attempts": 0, "locked_until": None,
        "email_verified": True, "updated_at": utcnow()}})
    await db.refresh_tokens.update_many({"user_id": user_id}, {"$set": {"revoked": True}})
    return {"message": "Password updated. Please log in."}


@router.get("/me", response_model=UserOut)
async def me(user=Depends(get_current_user)):
    return doc_out(user)
