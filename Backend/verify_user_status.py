import asyncio
import sys
import os

# Add the current directory to sys.path to make sure we can import app
sys.path.append(os.getcwd())

from sqlalchemy import select
from app.db.session import SessionLocal
from app.models.user import User

async def check_user():
    print("Checking user status...")
    async with SessionLocal() as session:
        email = "husselenspy2004@gmail.com"
        result = await session.execute(select(User).where(User.email == email))
        existing_user = result.scalars().first()
        
        if existing_user:
            print(f"User found: {existing_user.email}")
            print(f"ID: {existing_user.id_utilisateur}")
            print(f"Created at: {existing_user.created_at}")
            print(f"Updated at: {existing_user.updated_at}")
        else:
            print("User not found.")

if __name__ == "__main__":
    asyncio.run(check_user())
