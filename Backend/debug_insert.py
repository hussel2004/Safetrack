
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

# Database URL (Internal Docker Network)
DATABASE_URL = "postgresql+asyncpg://safetrack:safetrack_password@localhost:5432/safetrack_db"

async def test_insert():
    engine = create_async_engine(DATABASE_URL, echo=True)
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    async with async_session() as session:
        try:
            # Try to insert a vehicle manually to see the error
            stmt = text("""
                INSERT INTO vehicule (nom, marque, modele, annee, immatriculation, deveui, statut, moteur_coupe, created_at, updated_at, id_utilisateur_proprietaire)
                VALUES ('Test Car', 'Toyota', 'Corolla', 2020, 'CM123AB', '1122334455667788', 'ACTIF', false, now(), now(), 1)
                RETURNING id_vehicule
            """)
            result = await session.execute(stmt)
            await session.commit()
            print(f"Inserted Vehicle ID: {result.scalars().first()}")
        except Exception as e:
            print(f"Error: {e}")
        finally:
            await session.close()
    
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(test_insert())
