import asyncio
import httpx

BASE_URL = "http://127.0.0.1:8000/api/v1"

async def test_user_vehicles():
    async with httpx.AsyncClient() as client:
        # Login as husselenspy2004@gmail.com
        print("1. Login as husselenspy2004@gmail.com...")
        response = await client.post(
            f"{BASE_URL}/auth/login/access-token",
            data={"username": "husselenspy2004@gmail.com", "password": "admin123"},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code != 200:
            print(f"❌ Login failed: {response.status_code} - {response.text}")
            return
        
        token = response.json()["access_token"]
        print(f"✅ Login successful")
        
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        # Fetch vehicles
        print("\n2. Fetching vehicles...")
        response = await client.get(
            f"{BASE_URL}/vehicles/",
            headers=headers
        )
        
        if response.status_code != 200:
            print(f"❌ Failed to fetch vehicles: {response.status_code} - {response.text}")
            return
        
        vehicles = response.json()
        print(f"✅ Response received: {len(vehicles)} vehicles")
        
        if len(vehicles) == 0:
            print("⚠️  No vehicles returned!")
        else:
            for v in vehicles:
                print(f"\nVehicle:")
                print(f"  ID: {v.get('id_vehicule')}")
                print(f"  Name: {v.get('nom')}")
                print(f"  DevEUI: {v.get('deveui')}")
                print(f"  Owner ID: {v.get('id_utilisateur_proprietaire')}")

if __name__ == "__main__":
    asyncio.run(test_user_vehicles())
