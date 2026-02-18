import asyncio
import httpx
import json

BASE_URL = "http://127.0.0.1:8000/api/v1"
USERNAME = "admin@safetrack.com"
PASSWORD = "admin123"

async def test_integration():
    print("--- Testing Backend Integration ---")
    
    async with httpx.AsyncClient() as client:
        # 1. Login
        print("[Authentication]")
        response = await client.post(
            f"{BASE_URL}/auth/login/access-token",
            data={"username": USERNAME, "password": PASSWORD},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        if response.status_code != 200:
            print(f"❌ Login failed: {response.text}")
            return
        token = response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        print("✅ Login successful")

        # 2. Find/Create Vehicle
        print("\n[Vehicle Setup]")
        response = await client.get(f"{BASE_URL}/vehicles/", headers=headers)
        vehicles = response.json()
        target_vehicle = next((v for v in vehicles if v.get("deveui") == "71f118b4e8f86e22"), None)
        
        if not target_vehicle:
             print("⚠️ Target vehicle not found. Creating one with real DevEUI...")
             new_vehicle = {
                 "nom": "Real ChirpStack Device",
                 "deveui": "71f118b4e8f86e22",
                 "moteur_coupe": False,
                 "statut": "ACTIF"
             }
             create_resp = await client.post(f"{BASE_URL}/vehicles/", json=new_vehicle, headers=headers)
             if create_resp.status_code == 200:
                 target_vehicle = create_resp.json()
                 print("✅ Created new vehicle for test.")
             else:
                 print(f"❌ Failed to create vehicle: {create_resp.text}")
                 return

        print(f"Targeting Vehicle: {target_vehicle['nom']} (ID: {target_vehicle['id_vehicule']}, DevEUI: {target_vehicle['deveui']})")
        
        # 3. Send STOP Command (Update moteur_coupe = True)
        print("\n[Sending STOP Command via API]")
        vehicle_id = target_vehicle["id_vehicule"]
        
        # First ensure it's False
        await client.put(f"{BASE_URL}/vehicles/{vehicle_id}", json={"moteur_coupe": False}, headers=headers)
        
        # Now set to True
        response = await client.put(
            f"{BASE_URL}/vehicles/{vehicle_id}", 
            json={"moteur_coupe": True}, 
            headers=headers
        )
        
        if response.status_code == 200:
            print("✅ Vehicle updated (STOP triggered). Check backend logs for 'Downlink sent'.")
        else:
            print(f"❌ Failed to update vehicle: {response.status_code} - {response.text}")

        # 4. Create Active Zone
        print("\n[Creating Active Zone via API]")
        zone_data = {
            "nom": "Integration Test Zone",
            "type": "POLYGON",
            "active": True,
            "coordinates": [{"lat": 48.85, "lng": 2.35}, {"lat": 48.85, "lng": 2.36}, {"lat": 48.86, "lng": 2.36}, {"lat": 48.86, "lng": 2.35}],
            "latitude_centre": 48.85,
            "longitude_centre": 2.35,
            "rayon_metres": 100,
            "id_vehicule": vehicle_id
        }
        response = await client.post(f"{BASE_URL}/geofences/", json=zone_data, headers=headers)
        if response.status_code in [200, 201]:
             print("✅ Zone created. Check backend logs for 'Downlink sent'.")
        else:
             print(f"❌ Failed to create zone: {response.status_code} - {response.text}")

if __name__ == "__main__":
    asyncio.run(test_integration())
