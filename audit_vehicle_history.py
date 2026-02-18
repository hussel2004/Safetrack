
import requests
import json
import time

# Configuration
BACKEND_URL = "http://localhost:8000"
API_LOGIN = f"{BACKEND_URL}/api/v1/auth/login/access-token"
API_VEHICLES = f"{BACKEND_URL}/api/v1/vehicles/"
EMAIL = "husselenspy2004@gmail.com"
PASSWORD = "Hussel2004"

def audit_history():
    print(">> Authenticating...")
    try:
        login_resp = requests.post(API_LOGIN, data={"username": EMAIL, "password": PASSWORD})
        if login_resp.status_code != 200:
            print(f"!! Login failed: {login_resp.text}")
            return
        token = login_resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        print(">> Finding Vehicle 'Black Origin Tracker'...")
        vehicles_resp = requests.get(API_VEHICLES, headers=headers)
        vehicles = vehicles_resp.json()
        
        vehicle_id = None
        for v in vehicles:
            if v.get("deveui") == "71F118B4E8F86E22":
                vehicle_id = v["id_vehicule"]
                print(f"OK Found Vehicle: ID {vehicle_id} (DevEUI 71F118B4E8F86E22)")
                break
        
        if not vehicle_id:
            print("!! Vehicle not found.")
            return

        print(f">> Fetching History for Vehicle {vehicle_id}...")
        history_url = f"{BACKEND_URL}/api/v1/tracking/{vehicle_id}?limit=20"
        history_resp = requests.get(history_url, headers=headers)
        
        if history_resp.status_code != 200:
            print(f"!! Failed to fetch history: {history_resp.text}")
            return
            
        positions = history_resp.json()
        print(f"== Last {len(positions)} Positions ===")
        print(f"{'TIMESTAMP':<30} | {'LATITUDE':<10} | {'LONGITUDE':<10} | {'SPEED'}")
        print("-" * 70)
        for p in positions:
            print(f"{p.get('timestamp_gps'):<30} | {p.get('latitude'):<10} | {p.get('longitude'):<10} | {p.get('vitesse')}")
            
    except Exception as e:
        print(f"!! Error: {e}")

if __name__ == "__main__":
    audit_history()
