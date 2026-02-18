import asyncio
import httpx
import json

BASE_URL = "http://127.0.0.1:8000/api/v1"
USERNAME = "admin@safetrack.com"
PASSWORD = "admin123"

async def test_single_active_zone():
    print("--- Testing Single Active Zone Constraint ---")
    
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

        # 3. Create Zone A (Active)
        print("\n[1. Creating Zone A (Active)]")
        zone_a_data = {
            "nom": "Zone A",
            "type": "POLYGON",
            "active": True,
            "coordinates": [{"lat": 48.0, "lng": 2.0}, {"lat": 48.0, "lng": 2.1}, {"lat": 48.1, "lng": 2.1}],
            "latitude_centre": 48.05,
            "longitude_centre": 2.05,
            "rayon_metres": 1000,
            "id_vehicule": vehicle_id
        }
        res = await client.post(f"{BASE_URL}/geofences/", json=zone_a_data, headers=headers)
        zone_a = res.json()
        print(f"✅ Zone A Created (ID: {zone_a['id_zone']}, Active: {zone_a['active']})")

        await asyncio.sleep(1)

        # 4. Create Zone B (Active) - Should deactivate Zone A
        print("\n[2. Creating Zone B (Active)]")
        zone_b_data = {
            "nom": "Zone B",
            "type": "POLYGON",
            "active": True,
            "coordinates": [{"lat": 49.0, "lng": 3.0}, {"lat": 49.0, "lng": 3.1}, {"lat": 49.1, "lng": 3.1}],
            "latitude_centre": 49.05,
            "longitude_centre": 3.05,
            "rayon_metres": 1000,
            "id_vehicule": vehicle_id
        }
        res = await client.post(f"{BASE_URL}/geofences/", json=zone_b_data, headers=headers)
        zone_b = res.json()
        print(f"✅ Zone B Created (ID: {zone_b['id_zone']}, Active: {zone_b['active']})")

        # 5. Verify Zone A is now inactive
        print("\n[3. Verifying Zone A Status]")
        res = await client.get(f"{BASE_URL}/geofences/?vehicle_id={vehicle_id}", headers=headers)
        zones = res.json()
        
        zone_a_updated = next(z for z in zones if z['id_zone'] == zone_a['id_zone'])
        zone_b_updated = next(z for z in zones if z['id_zone'] == zone_b['id_zone'])
        
        print(f"Zone A Active Status: {zone_a_updated['active']}")
        print(f"Zone B Active Status: {zone_b_updated['active']}")
        
        if not zone_a_updated['active'] and zone_b_updated['active']:
            print("✅ SUCCESS: Zone A deactivated, Zone B active.")
        else:
            print("❌ FAILURE: Constraints not enforced.")

        # Cleanup
        await client.delete(f"{BASE_URL}/geofences/{zone_a['id_zone']}", headers=headers)
        await client.delete(f"{BASE_URL}/geofences/{zone_b['id_zone']}", headers=headers)

if __name__ == "__main__":
    asyncio.run(test_single_active_zone())
