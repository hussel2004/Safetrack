
import asyncio
import asyncpg

# Connection details
DB_CONFIG = {
    "user": "safetrack_user",
    "password": "safetrack_password",
    "database": "safetrack_db",
    "host": "db",
    "port": 5432
}

async def test_insert():
    conn = await asyncpg.connect(**DB_CONFIG)
    try:
        print("Connected to database.")
        
        # 1. Check if user 1 exists
        user_exists = await conn.fetchval("SELECT id_utilisateur FROM utilisateur WHERE id_utilisateur = 1")
        if not user_exists:
            print("User 1 does not exist. Creating...")
            await conn.execute("""
                INSERT INTO utilisateur (id_utilisateur, nom, prenom, email, mot_de_passe, role, statut, created_at)
                VALUES (1, 'Admin', 'User', 'admin@safetrack.com', 'hash', 'ADMIN', 'ACTIF', now())
            """)
        
        print("Attempting to insert vehicle...")
        row = await conn.fetchrow("""
            INSERT INTO vehicule (nom, marque, modele, annee, immatriculation, deveui, statut, moteur_coupe, id_utilisateur_proprietaire, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now(), now())
            RETURNING id_vehicule
        """, 'Test Car', 'Toyota', 'Corolla', 2020, 'CM-TEST-123', '1122334455667799', 'ACTIF', False, 1)
        
        print(f"Success! Vehicle ID: {row['id_vehicule']}")

    except Exception as e:
        print(f"Error during insertion: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(test_insert())
