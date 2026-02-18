#!/usr/bin/env python3
"""
Script de simulation ChirpStack → SafeTrack
Lit les uplinks GPS depuis un fichier JSON et les envoie au backend
"""

import json
import requests
import time
from datetime import datetime

# Configuration SafeTrack
BACKEND_URL = "http://localhost:8000"
API_LOGIN = f"{BACKEND_URL}/api/v1/auth/login/access-token"
API_VEHICLES = f"{BACKEND_URL}/api/v1/vehicles/"
API_TRACKING = f"{BACKEND_URL}/api/v1/tracking/"

# Authentification
EMAIL = "husselenspy2004@gmail.com"
PASSWORD = "Hussel2004"

# Fichier ChirpStack simulation
CHIRPSTACK_FILE = "chirpstack_route_melen_poste.json"

print("=" * 80)
print("🛰️  SIMULATION ChirpStack → SafeTrack")
print("   Lecture des uplinks GPS et envoi au backend")
print("=" * 80)
print()

# Étape 1: Connexion
print("🔐 Connexion au backend SafeTrack...")
try:
    login_response = requests.post(
        API_LOGIN,
        data={"username": EMAIL, "password": PASSWORD}
    )
    if login_response.status_code == 200:
        token = login_response.json()["access_token"]
        print(f"✅ Connecté en tant que {EMAIL}")
    else:
        print(f"❌ Échec de la connexion: {login_response.status_code}")
        exit(1)
except Exception as e:
    print(f"❌ Erreur de connexion: {e}")
    exit(1)

print()

# Étape 2: Charger les uplinks ChirpStack depuis le fichier
print(f"📂 Chargement des uplinks depuis {CHIRPSTACK_FILE}...")
try:
    with open(CHIRPSTACK_FILE, 'r', encoding='utf-8') as f:
        uplinks = json.load(f)
    print(f"✅ {len(uplinks)} uplinks chargés")
except FileNotFoundError:
    print(f"❌ Fichier {CHIRPSTACK_FILE} non trouvé")
    exit(1)
except json.JSONDecodeError as e:
    print(f"❌ Erreur de parsing JSON: {e}")
    exit(1)

print()

# Étape 3: Mapper DevEUI → vehicle_id
print("🔍 Recherche du véhicule...")
vehicle_mapping = {}  # DevEUI -> vehicle_id

try:
    vehicles_response = requests.get(
        API_VEHICLES,
        headers={"Authorization": f"Bearer {token}"}
    )
    if vehicles_response.status_code == 200:
        vehicles = vehicles_response.json()
        for v in vehicles:
            vehicle_mapping[v['deveui']] = v['id_vehicule']
        print(f"✅ {len(vehicle_mapping)} véhicules trouvés dans le système")
    else:
        print(f"❌ Erreur lors de la récupération des véhicules: {vehicles_response.status_code}")
        exit(1)
except Exception as e:
    print(f"❌ Erreur: {e}")
    exit(1)

print()
print("=" * 80)
print("🚀 ENVOI DES POSITIONS GPS")
print("=" * 80)
print()

# Étape 4: Traiter chaque uplink
success_count = 0
error_count = 0

for i, uplink in enumerate(uplinks, 1):
    # Extraire les informations
    dev_eui = uplink.get('deviceInfo', {}).get('devEui')
    
    if not dev_eui:
        print(f"⚠️  [{i:2d}/{len(uplinks)}] Uplink sans DevEUI, ignoré")
        error_count += 1
        continue
    
    # Trouver le vehicle_id
    vehicle_id = vehicle_mapping.get(dev_eui)
    if not vehicle_id:
        print(f"⚠️  [{i:2d}/{len(uplinks)}] DevEUI {dev_eui} non trouvé dans le système")
        error_count += 1
        continue
    
    # Extraire les données GPS
    gps_data = uplink.get('object', {})
    if not gps_data:
        print(f"⚠️  [{i:2d}/{len(uplinks)}] Pas de données GPS dans l'uplink")
        error_count += 1
        continue
    
    # Timestamp - Utiliser le temps actuel progressif au lieu du timestamp ChirpStack
    # Le backend attend un format ISO sans le 'Z' final
    from datetime import timedelta
    current_time = datetime.now() + timedelta(seconds=i * 2)
    timestamp = current_time.isoformat()
    
    # Déterminer le statut
    speed = gps_data.get('speed', 0.0)
    statut = "EN_MOUVEMENT" if speed > 5 else "ARRET"
    
    # Préparer les données pour SafeTrack
    position_data = {
        "id_vehicule": vehicle_id,
        "latitude": gps_data.get('latitude'),
        "longitude": gps_data.get('longitude'),
        "altitude": gps_data.get('altitude', 730.0),
        "vitesse": speed,
        "cap": gps_data.get('heading', 0.0),
        "timestamp_gps": timestamp,
        "fix_status": 1,
        "satellites": gps_data.get('satellites', 8),
        "hdop": None,
        "statut": statut,
        "dans_zone": None,
        "distance_zone_metres": None,
        "id_zone": None,
        "batterie_pourcentage": None,
        "payload_brut": f"CHIRPSTACK_UPLINK_FCNT_{uplink.get('fCnt', 0)}"
    }
    
    # Envoyer au backend
    try:
        response = requests.post(
            API_TRACKING,
            json=position_data,
            headers={"Authorization": f"Bearer {token}"},
            timeout=5
        )
        
        if response.status_code == 200:
            success_count += 1
            print(f"✅ [ID:{vehicle_id}] [{i:2d}/{len(uplinks)}] {gps_data['latitude']:.6f}, {gps_data['longitude']:.6f} | {speed:5.1f} km/h | FCnt: {uplink.get('fCnt', 'N/A')}")
        else:
            error_count += 1
            print(f"❌ [{i:2d}/{len(uplinks)}] Erreur {response.status_code}: {response.text[:100]}")
    
    except Exception as e:
        error_count += 1
        print(f"❌ [{i:2d}/{len(uplinks)}] Erreur réseau: {e}")
    
    # Délai entre les uplinks (simulation temps réel - augmenté pour éviter surcharge)
    time.sleep(1.5)

print()
print("=" * 80)
print(f"✅ SIMULATION TERMINÉE")
print(f"   Succès: {success_count}/{len(uplinks)}")
print(f"   Erreurs: {error_count}/{len(uplinks)}")
print("=" * 80)
print()
print("📱 Vérifiez l'application SafeTrack pour voir le trajet!")
print(f"   DevEUI: {dev_eui}")
print(f"   Véhicule ID: {vehicle_id}")
