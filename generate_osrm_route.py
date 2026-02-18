import requests
import json
import math
from datetime import datetime, timedelta

# Configuration
OSRM_URL = "http://router.project-osrm.org/route/v1/driving"
OUTPUT_FILE = "chirpstack_route_melen_poste.json"

# Waypoints: Total Melen (Start) -> Pharmacie Emia (End)
# Derived from Google Maps / existing data
WAYPOINTS = [
    (3.8594, 11.5134), # Total Melen (Start)
    (3.8480, 11.5020), # Pharmacie Emia (End)
]

def get_osrm_route(waypoints):
    # OSRM expects: lon,lat;lon,lat
    coords = ";".join([f"{lon},{lat}" for lat, lon in waypoints])
    url = f"{OSRM_URL}/{coords}?overview=full&geometries=geojson"
    
    print(f"🌍 Requesting OSRM route...")
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            if data['code'] == 'Ok':
                return data['routes'][0]['geometry']['coordinates'] # [[lon, lat], ...]
            else:
                print(f"❌ OSRM Error: {data['code']}")
        else:
            print(f"❌ HTTP Error: {response.status_code}")
    except Exception as e:
        print(f"❌ Exception: {e}")
    return None

def haversine_distance(coord1, coord2):
    R = 6371000 # Earth radius in meters
    lat1, lon1 = math.radians(coord1[1]), math.radians(coord1[0])
    lat2, lon2 = math.radians(coord2[1]), math.radians(coord2[0])
    
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c

def interpolate_route(coords, step_meters=5):
    # coords are [lon, lat]
    new_route = []
    
    for i in range(len(coords) - 1):
        p1 = coords[i]
        p2 = coords[i+1]
        
        dist = haversine_distance(p1, p2)
        if dist == 0:
            continue
            
        points_count = int(dist / step_meters)
        if points_count < 1:
            points_count = 1
            
        for j in range(points_count):
            t = j / points_count
            lon = p1[0] + (p2[0] - p1[0]) * t
            lat = p1[1] + (p2[1] - p1[1]) * t
            new_route.append((lon, lat))
            
    new_route.append(coords[-1])
    return new_route

def generate_chirpstack_json(route_coords):
    uplinks = []
    start_time = datetime.utcnow()
    
    for i, (lon, lat) in enumerate(route_coords):
        # Calculate speed (simulated: slow start, cruise, slow end)
        if i < 10 or i > len(route_coords) - 10:
            speed = 10.0 + (i % 5)
        else:
            speed = 40.0 + (i % 10)
            
        uplink = {
            "deduplicationId": f"sim-uuid-{i}",
            "time": (start_time + timedelta(seconds=i*3)).isoformat() + "Z",
            "deviceInfo": {
                "tenantId": "tenant-uuid",
                "tenantName": "SafeTrack",
                "applicationId": "app-uuid",
                "applicationName": "Vehicle Tracking",
                "deviceProfileId": "profile-uuid",
                "deviceProfileName": "GPS Tracker",
                "deviceName": "Black Origin Tracker",
                "devEui": "71F118B4E8F86E22", # Updated DevEUI
                "tags": {}
            },
            "object": {
                "latitude": lat,
                "longitude": lon,
                "altitude": 730.0,
                "speed": speed,
                "heading": 0.0, # Could calculate this but backend might not use it effectively yet
                "satellites": 8,
                "hdop": 1.0
            },
            "fCnt": i
        }
        uplinks.append(uplink)
        
    return uplinks

if __name__ == "__main__":
    coords = get_osrm_route(WAYPOINTS)
    if coords:
        print(f"✅ Route received: {len(coords)} raw points")
        
        # Interpolate for smooth animation (1 point every ~5 meters)
        smooth_route = interpolate_route(coords, step_meters=8)
        print(f"✨ Smoothed to: {len(smooth_route)} points")
        
        uplinks = generate_chirpstack_json(smooth_route)
        
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            json.dump(uplinks, f, indent=4)
            
        print(f"💾 Saved to {OUTPUT_FILE}")
    else:
        print("❌ Failed to get route")
