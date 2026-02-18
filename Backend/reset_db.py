import asyncio
import logging
from sqlalchemy import text
from app.db.session import SessionLocal

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def reset_db():
    async with SessionLocal() as session:
        logger.info("Starting database reset...")
        
        # Tables to truncate in dependency order (though CASCADE handles it)
        tables = [
            "alerte",
            "position_gps",
            "zone_securisee",
            "vehicule",
            "utilisateur"
        ]
        
        for table in tables:
            try:
                logger.info(f"Truncating table: {table}")
                await session.execute(text(f"TRUNCATE TABLE {table} CASCADE;"))
            except Exception as e:
                logger.error(f"Error truncating {table}: {e}")
        
        await session.commit()
        logger.info("Database reset complete. All data has been cleared.")

if __name__ == "__main__":
    asyncio.run(reset_db())
