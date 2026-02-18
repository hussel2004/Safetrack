#!/usr/bin/env python3
"""Script pour tester directement l'envoi de positions avec tous les IDs de véhicules possibles"""

import requests
import time

# Configuration
BACKEND_URL = "http://localhost:8000"
BACKEND_API_TRACKING = f"{BACKEND_URL}/api/v1/tracking/"
DEVEUI = "71F118B4E8F86E22"

print("=" * 70)
print("🔍 Recherche du véhicule avec DevEUI: 71F118B4E8F86E22")
print("=" * 70)
print()

# Essayer différents IDs de véhicule
found_id = None
for test_id in range(1, 50):
    try:
        # Position de test à Carrefour Emia
        test_position = {
            "id_vehicule": test_id,
            "latitude": 3.8480,
            "longitude": 11.5020,
            "altitude": 750.0,
            "vitesse": 0.0,
            "cap": 0.0,
            "timestamp_gps": "2026-02-13 09:00:00",
            "fix_status": 1,
            "satellites": 24,
            "statut": "ACTIF",
            "payload_brut": f"TEST:{DEVEUI}"
        }
        
        response = requests.post(BACKEND_API_TRACKING, json=test_position, timeout=2)
        
        if response.status_code == 200:
            found_id = test_id
            print(f"✅ Véhicule trouvé! ID = {test_id}")
            print(f"   Position de test envoyée avec succès!")
            break
        elif test_id % 5 == 0:
            print(f"   Testé jusqu'à l'ID {test_id}...")
            
    except Exception as e:
        continue

print()
if found_id:
    print("=" * 70)
    print(f"🎯 Véhicule ID: {found_id}")
    print("=" * 70)
    print()
    
    # Maintenant envoyer toutes les positions du trajet
    with open("gps_test_data.txt", 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    data_lines = [line.strip() for line in lines if line.strip() and not line.startswith('#')]
    
    print(f"📍 Envoi de {len(data_lines)} positions GPS...")
    print()
    
    for i, line in enumerate(data_lines, 1):
        parts = line.split(',')
        if len(parts) != 7:
            continue
        
        timestamp_str, lat, lon, vitesse, cap, altitude, satellites = parts
        
        position_data = {
            "id_vehicule": found_id,
            "latitude": float(lat),
            "longitude": float(lon),
            "altitude": float(altitude),
            "vitesse": float(vitesse),
            "cap": float(cap),
            "timestamp_gps": timestamp_str,
            "fix_status": 1,
            "satellites": int(satellites),
            "hdop": None,
            "statut": "ACTIF",
            "dans_zone": None,
            "distance_zone_metres": None,
            "id_zone": None,
            "batterie_pourcentage": None,
            "payload_brut": f"EMIA-MELEN:{DEVEUI}"
        }
        
        try:
            response = requests.post(BACKEND_API_TRACKING, json=position_data, timeout=5)
            if response.status_code == 200:
                print(f"✅ [{i}/{len(data_lines)}] {timestamp_str} - ({lat}, {lon}) - {vitesse} km/h")
            else:
                print(f"⚠️  [{i}/{len(data_lines)}] Erreur: {response.status_code}")
        except Exception as e:
            print(f"❌ [{i}/{len(data_lines)}] Erreur réseau: {e}")
        
        time.sleep(1)  # 1 seconde entre chaque position
    
    print()
    print("=" * 70)
    print("✅ Toutes les positions ont été envoyées!")
    print("📱 Consultez l'application pour voir le trajet!")
    print("=" * 70)
else:
    print("❌ Aucun véhicule trouvé (testé IDs 1-50)")
    print("💡 Veuillez créer un véhicule dans l'application")
