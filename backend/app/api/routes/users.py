from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.security import hash_password, verify_password
from app.schemas.auth import ChangePasswordIn
from app.schemas.common import Message
from app.schemas.user import UserOut, UserUpdate
from app.utils.helpers import doc_out, utcnow

router = APIRouter(prefix="/users", tags=["User profile"])


@router.get("/me", response_model=UserOut)
async def get_profile(user=Depends(get_current_user)):
    return doc_out(user)


@router.patch("/me", response_model=UserOut)
async def update_profile(data: UserUpdate, user=Depends(get_current_user), db=Depends(get_db)):
    changes = data.model_dump(exclude_unset=True)
    if changes:
        changes["updated_at"] = utcnow()
        await db.users.update_one({"_id": user["_id"]}, {"$set": changes})
        user.update(changes)
    return doc_out(user)


@router.post("/me/change-password", response_model=Message)
async def change_password(data: ChangePasswordIn, user=Depends(get_current_user), db=Depends(get_db)):
    if not verify_password(data.current_password, user.get("password_hash")):
        raise HTTPException(400, "Current password is incorrect")
    await db.users.update_one({"_id": user["_id"]},
                              {"$set": {"password_hash": hash_password(data.new_password), "updated_at": utcnow()}})
    await db.refresh_tokens.update_many({"user_id": user["_id"]}, {"$set": {"revoked": True}})
    return {"message": "Password changed. Please log in again on your other devices."}


@router.delete("/me", response_model=Message)
async def delete_account(user=Depends(get_current_user), db=Depends(get_db)):
    """Soft-deletes and anonymises the account (orders are kept for accounting)."""
    await db.users.update_one({"_id": user["_id"]}, {"$set": {
        "email": f"deleted_{user['_id']}@deleted.local", "full_name": "Deleted user", "phone": None,
        "password_hash": None, "is_active": False, "is_deleted": True, "updated_at": utcnow()}})
    await db.refresh_tokens.update_many({"user_id": user["_id"]}, {"$set": {"revoked": True}})
    await db.saved_recipes.delete_many({"user_id": user["_id"]})
    await db.carts.delete_many({"owner_key": f"user:{user['_id']}"})
    return {"message": "Account deleted"}
