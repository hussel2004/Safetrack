import asyncio
import httpx
import json

BASE_URL = "http://127.0.0.1:8000/api/v1"
USERNAME = "admin@safetrack.com"
PASSWORD = "admin123"

async def test_active_logic():
    print("--- Testing Geofence Active/Inactive Logic ---")
    
    async with httpx.AsyncClient() as client:
        # 1. Login
        response = await client.post(
            f"{BASE_URL}/auth/login/access-token",
            data={"username": USERNAME, "password": PASSWORD},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        token = response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        print("✅ Login successful")

        # 2. Find Vehicle
        response = await client.get(f"{BASE_URL}/vehicles/", headers=headers)
        vehicles = response.json()
        target_vehicle = next((v for v in vehicles if v.get("deveui") == "71f118b4e8f86e22"), None)
        if not target_vehicle:
             target_vehicle = next((v for v in vehicles if v.get("deveui")), None)
        
        if not target_vehicle:
            print("❌ No vehicle available.")
            return

        vehicle_id = target_vehicle['id_vehicule']
        print(f"Target Vehicle: {target_vehicle['nom']} (ID: {vehicle_id})")

        # 3. Create INACTIVE Zone (Should NOT trigger downlink)
        print("\n[1. Creating INACTIVE Zone]")
        zone_data = {
            "nom": "Inactive Test Zone",
            "type": "POLYGON",
            "active": False,
            "coordinates": [{"lat": 48.0, "lng": 2.0}, {"lat": 48.0, "lng": 2.1}, {"lat": 48.1, "lng": 2.1}],
            "latitude_centre": 48.05,
            "longitude_centre": 2.05,
            "rayon_metres": 1000,
            "id_vehicule": vehicle_id
        }
        res = await client.post(f"{BASE_URL}/geofences/", json=zone_data, headers=headers)
        zone = res.json()
        print(f"✅ Inactive Zone Created (ID: {zone['id_zone']}). Check logs: SHOULD be empty.")
        await asyncio.sleep(1)

        # 4. Activate Zone (Should trigger Downlink)
        print("\n[2. Activating Zone]")
        res = await client.put(f"{BASE_URL}/geofences/{zone['id_zone']}", json={"active": True}, headers=headers)
        print(f"✅ Zone Activated. Check logs: SHOULD see Downlink.")
        await asyncio.sleep(1)

        # 5. Deactivate Zone (Should trigger Clear)
        print("\n[3. Deactivating Zone]")
        res = await client.put(f"{BASE_URL}/geofences/{zone['id_zone']}", json={"active": False}, headers=headers)
        print(f"✅ Zone Deactivated. Check logs: SHOULD see Clearing/Empty Downlink.")
        await asyncio.sleep(1)

        # 6. Delete Inactive Zone (Should NOT trigger Downlink)
        print("\n[4. Deleting Inactive Zone]")
        res = await client.delete(f"{BASE_URL}/geofences/{zone['id_zone']}", headers=headers)
        print(f"✅ Inactive Zone Deleted. Check logs: SHOULD be empty.")

if __name__ == "__main__":
    asyncio.run(test_active_logic())
