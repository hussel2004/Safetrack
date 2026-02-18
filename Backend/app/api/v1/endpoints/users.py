from typing import Any, List

from fastapi import APIRouter, Body, Depends, HTTPException, status
from fastapi.encoders import jsonable_encoder
from pydantic import EmailStr
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.api import deps
from app.core import security
from app.models.user import User, UserStatus
from app.schemas import user as schemas

router = APIRouter()

@router.get("/me", response_model=schemas.User)
async def read_user_me(
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Get current user.
    """
    return current_user

@router.put("/me", response_model=schemas.User)
async def update_user_me(
    *,
    db: AsyncSession = Depends(deps.get_db),
    user_in: schemas.UserUpdate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Update own user.
    """
    current_user_data = jsonable_encoder(current_user)
    user_in_data = user_in.dict(exclude_unset=True)

    # Prevent role update by user
    if 'role' in user_in_data:
        del user_in_data['role']

    # Update password if provided
    if user_in_data.get("mot_de_passe"):
        hashed_password = security.get_password_hash(user_in_data["mot_de_passe"])
        del user_in_data["mot_de_passe"]
        current_user.mot_de_passe = hashed_password

    # Update other fields
    for field in user_in_data:
        if field in current_user_data:
            setattr(current_user, field, user_in_data[field])

    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user

@router.delete("/me", response_model=schemas.User)
async def delete_user_me(
    *,
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Delete own user (Soft delete: set status to INACTIF).
    """
    # Soft delete
    current_user.statut = UserStatus.INACTIF.value # Accessing value of Enum
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)
    return current_user
