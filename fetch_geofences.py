import requests
import json

# Configuration
BACKEND_URL = "http://localhost:8000"
API_LOGIN = f"{BACKEND_URL}/api/v1/auth/login/access-token"
API_GEOFENCES = f"{BACKEND_URL}/api/v1/geofences/"
EMAIL = "husselenspy2004@gmail.com"
PASSWORD = "Hussel2004"

def get_geofences():
    # Login
    try:
        login_response = requests.post(
            API_LOGIN,
            data={"username": EMAIL, "password": PASSWORD}
        )
        if login_response.status_code != 200:
            print(f"❌ Login failed: {login_response.status_code}")
            return
        
        token = login_response.json()["access_token"]
        print("✅ Logged in")
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return

    # Fetch Geofences
    try:
        response = requests.get(
            API_GEOFENCES,
            headers={"Authorization": f"Bearer {token}"}
        )
        
        if response.status_code == 200:
            zones = response.json()
            print(f"✅ Found {len(zones)} zones")
            for zone in zones:
                if zone.get('active') and zone.get('type') == 'POLYGON':
                    print(f"✅ Found active polygon zone: {zone.get('nom')}")
                    coords = zone.get('coordinates', [])
                    
                    with open("active_zone_coords.json", "w") as f:
                        json.dump(coords, f, indent=2)
                    print(f"✅ Saved {len(coords)} points to active_zone_coords.json")
                    break 
        else:
            print(f"❌ Failed to fetch zones: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Error fetching zones: {e}")

if __name__ == "__main__":
    get_geofences()
