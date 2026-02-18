from app.core import security
from app.db.session import SessionLocal
from app.models.user import User
import asyncio

async def fix_admin():
    new_hash = security.get_password_hash("admin123")
    print(f"Generated hash: {new_hash}")
    
    # Check verification immediately
    verify = security.verify_password("admin123", new_hash)
    print(f"Immediate verification: {verify}")

    async with SessionLocal() as session:
        from sqlalchemy.future import select
        result = await session.execute(select(User).where(User.email == "admin@safetrack.com"))
        user = result.scalars().first()
        if user:
            user.mot_de_passe = new_hash
            await session.commit()
            print("Updated admin password hash in DB")
        else:
            print("Admin user not found")

if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(fix_admin())
