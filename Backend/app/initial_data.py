import asyncio
import logging
from sqlalchemy.ext.asyncio import AsyncSession
from app.core import security
from app.db.session import SessionLocal
from app.models.user import User, UserRole, UserStatus
from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def init_db(db: AsyncSession) -> None:
    # Check if admin user exists
    from sqlalchemy.future import select
    result = await db.execute(select(User).where(User.email == "admin@safetrack.com"))
    user = result.scalars().first()
    
    if not user:
        logger.info("Creating initial superuser")
        user = User(
            email="admin@safetrack.com",
            nom="Admin",
            prenom="System",
            mot_de_passe=security.get_password_hash("admin123"),
            role=UserRole.ADMIN,
            statut=UserStatus.ACTIF,
        )
        db.add(user)
        await db.commit()
    else:
        logger.info("Superuser already exists")

async def main() -> None:
    logger.info("Creating initial data")
    async with SessionLocal() as session:
        await init_db(session)
    logger.info("Initial data created")

if __name__ == "__main__":
    asyncio.run(main())
