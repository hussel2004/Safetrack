#!/usr/bin/env python3
"""Test simple d'envoi d'une position GPS"""

import requests

API_TRACKING = "http://localhost:8000/api/v1/tracking/"

# Position de test simple
position_data = {
    "id_vehicule": 14,
    "latitude": 3.8480,
    "longitude": 11.5020,
    "altitude": 750.0,
    "vitesse": 0.0,
    "cap": 0.0,
    "timestamp_gps": "2026-02-13T09:00:00",  # Format ISO
    "fix_status": 1,
    "satellites": 24,
    "statut": "ACTIF",
    "payload_brut": "TEST"
}

print("📍 Test d'envoi de position GPS...")
print(f"   Position: ({position_data['latitude']}, {position_data['longitude']})")
print()

try:
    response = requests.post(API_TRACKING, json=position_data, timeout=5)
    print(f"Response: {response.status_code}")
    print(f"Body: {response.text}")
except Exception as e:
    print(f"❌ Erreur: {e}")
