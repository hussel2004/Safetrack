#!/usr/bin/env python3
"""
Générateur de route GPS complète: Total Melen 1 → Poste Centrale
Crée un fichier JSON au format ChirpStack avec 50 positions GPS
"""

import json
from datetime import datetime, timedelta

# Coordonnées exactes (Yaoundé)
START_LAT = 3.868779  # Total Melen
START_LON = 11.496586
END_LAT = 3.864353    # Poste Centrale
END_LON = 11.517374

NUM_POINTS = 100
DEVEUI = "71F118B4E8F86E22"

def generate_route_uplinks(start_lat, start_lon, end_lat, end_lon, num_points):
    """Génère des uplinks ChirpStack pour un trajet GPS"""
    uplinks = []
    base_time = datetime.now()
    
    for i in range(num_points):
        # Interpolation linéaire
        ratio = i / (num_points - 1)
        lat = start_lat + (end_lat - start_lat) * ratio
        lon = start_lon + (end_lon - start_lon) * ratio
        
        # Vitesse variable (profil réaliste)
        if i < 5:
            speed = 10 + i * 5  # Accélération
        elif i > num_points - 10:
            speed = max(5, 50 - (num_points - i) * 3)  # Décélération
        else:
            speed = 40 + (i % 10) * 2  # Vitesse normale variable
        
        # Timestamp progressif (2 secondes entre chaque point)
        timestamp = (base_time + timedelta(seconds=i * 2)).isoformat() + "Z"
        
        # Créer l'uplink au format ChirpStack
        uplink = {
            "deduplicationId": f"sim-{i:03d}-{DEVEUI}",
            "time": timestamp,
            "deviceInfo": {
                "tenantId": "52f14cd4-c6f1-4fbd-8f87-4025e1d49242",
                "tenantName": "SafeTrack",
                "applicationId": "ca73f355-7fc6-4653-8c0f-b1c8c5c9d67b",
                "applicationName": "Vehicle Tracking",
                "deviceProfileId": "605d08d4-65f1-4d55-92cc-f93757a8eb23",
                "deviceProfileName": "GPS Tracker",
                "deviceName": "Black Origin Tracker",
                "devEui": DEVEUI,
                "deviceClassEnabled": "CLASS_A"
            },
            "devAddr": "20000001",
            "adr": True,
            "dr": 5,
            "fCnt": 100 + i,
            "fPort": 2,
            "confirmed": False,
            "object": {
                "latitude": round(lat, 7),
                "longitude": round(lon, 7),
                "speed": round(speed, 1),
                "heading": 45.0,
                "altitude": 730.0,
                "satellites": 8 if i % 3 != 0 else 9  # Variation satellites
            },
            "rxInfo": [
                {
                    "gatewayId": "0016c001f0000001",
                    "rssi": -57 - (i % 5),  # RSSI variable
                    "snr": 9.5 - (i % 3) * 0.5  # SNR variable
                }
            ]
        }
        
        uplinks.append(uplink)
    
    return uplinks

# Générer la route
print("=" * 80)
print("🗺️  GÉNÉRATEUR DE ROUTE GPS - ChirpStack Format")
print("=" * 80)
print()
print(f"📍 Départ: Total Melen 1 ({START_LAT}, {START_LON})")
print(f"📍 Arrivée: Poste Centrale ({END_LAT}, {END_LON})")
print(f"📊 Nombre de points: {NUM_POINTS}")
print(f"🚗 DevEUI: {DEVEUI}")
print()

uplinks = generate_route_uplinks(START_LAT, START_LON, END_LAT, END_LON, NUM_POINTS)

# Sauvegarder dans un fichier JSON
output_file = "chirpstack_route_melen_poste.json"
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(uplinks, f, indent=2, ensure_ascii=False)

print(f"✅ Route générée et sauvegardée dans: {output_file}")
print()
print("📊 Statistiques de la route:")
print(f"   - Premier point: {uplinks[0]['time']}")
print(f"   - Dernier point: {uplinks[-1]['time']}")
print(f"   - Vitesse min: {min(u['object']['speed'] for u in uplinks):.1f} km/h")
print(f"   - Vitesse max: {max(u['object']['speed'] for u in uplinks):.1f} km/h")
print(f"   - FCnt: {uplinks[0]['fCnt']} → {uplinks[-1]['fCnt']}")
print()
print("🚀 Pour envoyer au backend SafeTrack, exécutez:")
print(f"   python chirpstack_to_safetrack.py")
print()
print("   (Modifiez d'abord CHIRPSTACK_FILE dans le script)")
