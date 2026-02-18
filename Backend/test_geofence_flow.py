import asyncio
import httpx
import sys

BASE_URL = "http://127.0.0.1:8000/api/v1"

async def test_geofence_flow():
    async with httpx.AsyncClient() as client:
        # 1. Login
        print("1. Login...")
        response = await client.post(
            f"{BASE_URL}/auth/login/access-token",
            data={"username": "admin@safetrack.com", "password": "admin123"},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        if response.status_code != 200:
            print(f"❌ Login failed: {response.status_code} - {response.text}")
            return
        
        token = response.json()["access_token"]
        print(f"✅ Login successful, token: {token[:20]}...")
        
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        # 2. Create a test vehicle
        print("\n2. Creating test vehicle...")
        vehicle_data = {
            "nom": "Test Vehicle Flow",
            "marque": "Test Brand",
            "modele": "Test Model",
            "annee": 2024,
            "immatriculation": "TEST-FLOW-001",
            "deveui": "AABBCCDDEEFF0011",
            "appeui": "1122334455667788",
            "appkey": "AABBCCDDEEFF00112233445566778899",
            "statut": "ACTIF",
            "moteur_coupe": False
        }
        
        response = await client.post(
            f"{BASE_URL}/vehicles/",
            json=vehicle_data,
            headers=headers
        )
        
        if response.status_code not in [200, 201]:
            print(f"❌ Vehicle creation failed: {response.status_code} - {response.text}")
            return
            
        vehicle = response.json()
        vehicle_id = vehicle["id_vehicule"]
        print(f"✅ Vehicle created with ID: {vehicle_id}")
        
        # 3. Create a polygon zone
        print("\n3. Creating polygon zone...")
        zone_data = {
            "nom": "Test Polygon Zone",
            "description": "Testing polygon geofence flow",
            "latitude_centre": 48.855,
            "longitude_centre": 2.355,
            "rayon_metres": 1000,
            "couleur": "#00FF00",
            "active": True,
            "type": "POLYGON",
            "coordinates": [
                {"lat": 48.85, "lng": 2.35},
                {"lat": 48.85, "lng": 2.36},
                {"lat": 48.86, "lng": 2.36},
                {"lat": 48.86, "lng": 2.35}
            ],
            "id_vehicule": vehicle_id
        }
        
        response = await client.post(
            f"{BASE_URL}/geofences/",
            json=zone_data,
            headers=headers
        )
        
        if response.status_code not in [200, 201]:
            print(f"❌ Zone creation failed: {response.status_code} - {response.text}")
            return
            
        zone = response.json()
        zone_id = zone["id_zone"]
        print(f"✅ Zone created with ID: {zone_id}")
        print(f"   Type: {zone.get('type')}")
        print(f"   Coordinates: {zone.get('coordinates')}")
        
        # 4. Verify zone exists in list
        print("\n4. Fetching zones to verify...")
        response = await client.get(
            f"{BASE_URL}/geofences/",
            headers=headers
        )
        
        if response.status_code == 200:
            zones = response.json()
            our_zone = next((z for z in zones if z["id_zone"] == zone_id), None)
            if our_zone:
                print(f"✅ Zone found in list")
                print(f"   Name: {our_zone['nom']}")
                print(f"   Type: {our_zone.get('type')}")
                print(f"   Has coordinates: {bool(our_zone.get('coordinates'))}")
                print(f"   Number of points: {len(our_zone.get('coordinates', []))}")
            else:
                print("❌ Zone not found in list!")
        else:
            print(f"❌ Failed to fetch zones: {response.status_code}")
        
        print("\n✅ Test completed successfully!")
        print("\nNow check the database with:")
        print(f"  SELECT id_zone, nom, type, coordinates FROM zone_securisee WHERE id_zone = {zone_id};")

if __name__ == "__main__":
    asyncio.run(test_geofence_flow())
