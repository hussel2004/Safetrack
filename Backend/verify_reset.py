import asyncio
from sqlalchemy import text
from app.db.session import SessionLocal

async def verify():
    async with SessionLocal() as session:
        result = await session.execute(text("SELECT count(*) FROM utilisateur"))
        count = result.scalar()
        print(f"USER_COUNT: {count}")

if __name__ == "__main__":
    asyncio.run(verify())
