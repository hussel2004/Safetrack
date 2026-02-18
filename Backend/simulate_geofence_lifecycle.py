import asyncio
import httpx
import json

BASE_URL = "http://127.0.0.1:8000/api/v1"
USERNAME = "admin@safetrack.com"
PASSWORD = "admin123"

async def test_lifecycle():
    print("--- Testing Geofence Lifecycle (Create -> Update -> Delete) ---")
    
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

        # 2. Find a Vehicle with DevEUI
        response = await client.get(f"{BASE_URL}/vehicles/", headers=headers)
        vehicles = response.json()
        target_vehicle = next((v for v in vehicles if v.get("deveui") == "71f118b4e8f86e22"), None)
        
        if not target_vehicle:
            print("⚠️ Vehicle 71f118b4e8f86e22 not found, using first available or failing.")
            target_vehicle = next((v for v in vehicles if v.get("deveui")), None)
            
        if not target_vehicle:
            print("❌ No vehicle available.")
            return

        vehicle_id = target_vehicle['id_vehicule']
        print(f"Target Vehicle: {target_vehicle['nom']} (ID: {vehicle_id}, DevEUI: {target_vehicle['deveui']})")

        # 3. Create Zone
        print("\n[1. Creating Zone]")
        zone_data = {
            "nom": "Lifecycle Test Zone",
            "type": "POLYGON",
            "active": True,
            "coordinates": [{"lat": 48.0, "lng": 2.0}, {"lat": 48.0, "lng": 2.1}, {"lat": 48.1, "lng": 2.1}, {"lat": 48.1, "lng": 2.0}],
            "latitude_centre": 48.05,
            "longitude_centre": 2.05,
            "rayon_metres": 1000,
            "id_vehicule": vehicle_id
        }
        res = await client.post(f"{BASE_URL}/geofences/", json=zone_data, headers=headers)
        if res.status_code not in [200, 201]:
            print(f"❌ Create failed: {res.text}")
            return
        zone = res.json()
        print(f"✅ Zone Created (ID: {zone['id_zone']}). Check logs for Downlink.")
        await asyncio.sleep(1)

        # 4. Update Zone
        print("\n[2. Updating Zone]")
        update_data = {
            "nom": "Lifecycle Test Zone UPDATED",
            "coordinates": [{"lat": 49.0, "lng": 3.0}, {"lat": 49.0, "lng": 3.1}, {"lat": 49.1, "lng": 3.1}, {"lat": 49.1, "lng": 3.0}]
        }
        res = await client.put(f"{BASE_URL}/geofences/{zone['id_zone']}", json=update_data, headers=headers)
        if res.status_code == 200:
            print(f"✅ Zone Updated. Check logs for NEW Downlink (different points).")
        else:
            print(f"❌ Update failed: {res.text}")
        await asyncio.sleep(1)

        # 5. Delete Zone
        print("\n[3. Deleting Zone]")
        res = await client.delete(f"{BASE_URL}/geofences/{zone['id_zone']}", headers=headers)
        if res.status_code == 200:
            print(f"✅ Zone Deleted. Check logs for EMPTY Downlink (Clear command).")
        else:
            print(f"❌ Delete failed: {res.text}")

if __name__ == "__main__":
    asyncio.run(test_lifecycle())
