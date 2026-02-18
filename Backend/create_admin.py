import asyncio
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import SessionLocal
from app.models.user import User, UserRole, UserStatus

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

async def create_admin():
    async with SessionLocal() as session:
        # Create admin user
        hashed_password = pwd_context.hash("admin123")
        user = User(
            email="admin@safetrack.com",
            nom="Admin",
            prenom="System",
            mot_de_passe=hashed_password,
            role=UserRole.ADMIN,
            statut=UserStatus.ACTIF,
        )
        session.add(user)
        await session.commit()
        print("Admin user created successfully!")

if __name__ == "__main__":
    asyncio.run(create_admin())
