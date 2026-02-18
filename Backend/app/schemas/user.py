from typing import Optional
from pydantic import BaseModel, EmailStr
from app.models.user import UserRole, UserStatus

class UserBase(BaseModel):
    email: EmailStr
    nom: str
    prenom: str
    telephone: Optional[str] = None
    role: UserRole = UserRole.GESTIONNAIRE

class UserCreate(UserBase):
    mot_de_passe: str

class UserUpdate(UserBase):
    mot_de_passe: Optional[str] = None

class UserInDBBase(UserBase):
    id_utilisateur: int
    statut: UserStatus
    
    class Config:
        from_attributes = True

class User(UserInDBBase):
    pass
