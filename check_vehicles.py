import requests
import json

# Configuration
BACKEND_URL = "http://localhost:8000"
API_LOGIN = f"{BACKEND_URL}/api/v1/auth/login/access-token"
API_VEHICLES = f"{BACKEND_URL}/api/v1/vehicles/"
EMAIL = "husselenspy2004@gmail.com"
PASSWORD = "Hussel2004"

def check_vehicles():
    try:
        # Login
        login_response = requests.post(
            API_LOGIN,
            data={"username": EMAIL, "password": PASSWORD}
        )
        token = login_response.json()["access_token"]
        
        # Get Vehicles
        response = requests.get(
            API_VEHICLES,
            headers={"Authorization": f"Bearer {token}"}
        )
        
        output = []
        output.append("="*60)
        output.append(f"{'ID':<5} | {'Name':<20} | {'DevEUI':<20} | {'Status'}")
        output.append("="*60)
        
        for v in response.json():
            output.append(f"{v['id_vehicule']:<5} | {v['nom']:<20} | {v['deveui']:<20} | {v['statut']}")
            
        output.append("="*60)
        
        with open("vehicles_list.txt", "w") as f:
            f.write("\n".join(output))
            
        print("✅ Saved vehicle list to vehicles_list.txt")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_vehicles()
