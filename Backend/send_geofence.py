import asyncio
import httpx
import base64
import json
import struct

# Configuration
BASE_URL = "http://127.0.0.1:8000/api/v1"
USERNAME = "admin@safetrack.com"
PASSWORD = "admin123"

# Define the figure (polygon) points
# Example: A square around a central point
FIGURE_POINTS = [
    {"lat": 48.8500, "lng": 2.3500},
    {"lat": 48.8500, "lng": 2.3600},
    {"lat": 48.8600, "lng": 2.3600},
    {"lat": 48.8600, "lng": 2.3500}
]

def string_to_base64(text: str) -> str:
    """
    Mimics the command: echo "text" | base64
    """
    encoded_bytes = base64.b64encode(text.encode("utf-8"))
    return encoded_bytes.decode("utf-8")

async def send_geofence():
    print(f"--- Sending Figure to Backend ---")
    
    # 1. Base64 Demo (as requested)
    text_to_encode = "Hello bryan"
    encoded_text = string_to_base64(text_to_encode)
    print(f"\n[Base64 Demo]")
    print(f"Input: '{text_to_encode}'")
    print(f"Base64: {encoded_text}")
    print(f"(Equivalent to: echo \"{text_to_encode}\" | base64)\n")

    async with httpx.AsyncClient() as client:
        # 2. Login
        print("[Authentication]")
        print(f"Logging in as {USERNAME}...")
        try:
            response = await client.post(
                f"{BASE_URL}/auth/login/access-token",
                data={"username": USERNAME, "password": PASSWORD},
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            
            if response.status_code != 200:
                print(f"❌ Login failed: {response.status_code} - {response.text}")
                return

            token = response.json()["access_token"]
            print("✅ Login successful")
            
            headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            }
        except httpx.ConnectError:
            print(f"❌ Could not connect to {BASE_URL}. Is the backend running?")
            return

        # 2.5 Find a valid vehicle with DevEUI (Required for ChirpStack)
        print("\n[Vehicle Selection]")
        response = await client.get(f"{BASE_URL}/vehicles/", headers=headers)
        if response.status_code != 200:
            print(f"❌ Failed to fetch vehicles: {response.text}")
            return
            
        vehicles = response.json()
        target_vehicle = next((v for v in vehicles if v.get("deveui")), None)
        
        if target_vehicle:
            print(f"✅ Found vehicle with DevEUI: {target_vehicle['nom']} (ID: {target_vehicle['id_vehicule']})")
            print(f"   DevEUI: {target_vehicle['deveui']}")
            vehicle_id = target_vehicle["id_vehicule"]
        else:
            print("⚠️ No vehicle with DevEUI found. Creating a temporary one...")
            new_vehicle = {
                "nom": "Script Temp Vehicle",
                "marque": "Test",
                "modele": "Test",
                "annee": 2024,
                "immatriculation": "SCRIPT-001",
                "deveui": "AABBCCDDEEFF0099", # Example EUI
                "statut": "ACTIF"
            }
            create_resp = await client.post(f"{BASE_URL}/vehicles/", json=new_vehicle, headers=headers)
            if create_resp.status_code in [200, 201]:
                vehicle_id = create_resp.json()["id_vehicule"]
                print(f"✅ Created new vehicle with ID: {vehicle_id}")
            else:
                print(f"❌ Failed to create vehicle: {create_resp.text}")
                return

        # 3. Create Geofence Payload
        geofence_data = {
            "nom": "ChirpStack Trigger Zone",
            "description": "Zone created to test ChirpStack downlink",
            "type": "POLYGON",
            "active": True,
            "couleur": "#FF5733",
            "coordinates": FIGURE_POINTS,
            # Required fields for backend validation even if ignored for POLYGON type
            "latitude_centre": FIGURE_POINTS[0]["lat"],
            "longitude_centre": FIGURE_POINTS[0]["lng"],
            "rayon_metres": 1,
            "id_vehicule": vehicle_id
        }

        # 4. Send to Backend
        print(f"\n[Sending Geofence]")
        print(f"Posting {len(FIGURE_POINTS)} points to {BASE_URL}/geofences/...")
        
        response = await client.post(
            f"{BASE_URL}/geofences/",
            json=geofence_data,
            headers=headers
        )

        if response.status_code in [200, 201]:
            zone = response.json()
            print(f"✅ Geofence created successfully!")
            print(f"ID: {zone['id_zone']}")
            print(f"Name: {zone['nom']}")
            print(f"Type: {zone['type']}")
            print(f"Points: {len(zone['coordinates'])}")
            
            # 5. Direct ChirpStack Push (User Request)
            print("\n[Direct ChirpStack Push]")
            
            # Settings provided by user
            CS_URL = "http://192.168.1.102:8080"
            CS_API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcGlfa2V5X2lkIjoiNzNlZTI0M2YtZjczYi00ODU1LWJkZWYtNWViYjVmZjZiMGZjIiwiYXVkIjoiYXMiLCJpc3MiOiJhcyIsIm5iZiI6MTc3MDgzODkyOSwic3ViIjoiYXBpX2tleSJ9.NmWQ_FKMEXcZ0XdeblO3DEAe-Cp7r1GSp3-r8rPtAKg"
            
            # Use the vehicle's DevEUI if found, otherwise use user's example
            target_deveui = vehicle_data.get("deveui") if 'vehicle_data' in locals() and vehicle_id else "71f118b4e8f86e22"
            # Actually, let's use the one we found/created to be consistent, but fallback to user's
            if 'target_vehicle' in locals() and target_vehicle:
                 target_deveui = target_vehicle["deveui"]
            
            print(f"Targeting DevEUI: {target_deveui}")
            
            # Encode Geofence to Base64 (Binary Protocol)
            # Helper to pack floats
            def pack_polygon(points):
                # Type 0x02 + Num Points
                payload = struct.pack(">BB", 0x02, len(points))
                for pt in points:
                    payload += struct.pack(">ff", float(pt["lat"]), float(pt["lng"]))
                return base64.b64encode(payload).decode("utf-8")

            encoded_data = pack_polygon(FIGURE_POINTS)
            print(f"Encoded Geofence Data (Base64): {encoded_data}")
            
            # Construct CURL command for display
            curl_cmd = f"""curl -X POST "{CS_URL}/api/devices/{target_deveui}/queue" \\
  -H "Content-Type: application/json" \\
  -H "Grpc-Metadata-Authorization: Bearer {CS_API_KEY}" \\
  -d '{{
    "deviceQueueItem": {{
      "confirmed": false,
      "fPort": 10,
      "data": "{encoded_data}"
    }}
  }}'"""
            
            print("\nGenerated CURL Command:")
            print(curl_cmd)
            
            # Execute it
            print(f"\nSending via Python to {CS_URL}...")
            cs_headers = {
                "Content-Type": "application/json",
                "Grpc-Metadata-Authorization": f"Bearer {CS_API_KEY}"
            }
            cs_payload = {
                "deviceQueueItem": {
                    "confirmed": False,
                    "fPort": 10,
                    "data": encoded_data
                }
            }
            
            try:
                cs_response = await client.post(
                    f"{CS_URL}/api/devices/{target_deveui}/queue",
                    json=cs_payload,
                    headers=cs_headers,
                    timeout=5.0
                )
                if cs_response.status_code == 200:
                    print("✅ ChirpStack Push Successful!")
                else:
                    print(f"❌ ChirpStack Push Failed: {cs_response.status_code} - {cs_response.text}")
            except Exception as e:
                print(f"❌ Failed to reach ChirpStack: {e}")

        else:
            print(f"❌ Failed to create geofence: {response.status_code}")
            print(f"Response: {response.text}")

if __name__ == "__main__":
    try:
        asyncio.run(send_geofence())
    except ImportError:
        print("❌ Error: 'httpx' library is required.")
        print("Run: pip install httpx")
    except Exception as e:
        print(f"❌ An error occurred: {e}")
