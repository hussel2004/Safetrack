#!/usr/bin/env python3
"""Vérifier les véhicules et trouver celui avec DevEUI 71F118B4E8F86E22"""

import requests

BACKEND_URL = "http://localhost:8000"
API_LOGIN = f"{BACKEND_URL}/api/v1/auth/login/access-token"
API_VEHICLES = f"{BACKEND_URL}/api/v1/vehicles/"

EMAIL = "husselenspy2004@gmail.com"
PASSWORD = "Hussel2004"

print("🔐 Connexion...")
login_response = requests.post(API_LOGIN, data={"username": EMAIL, "password": PASSWORD})
token = login_response.json()["access_token"]
print("✅ Connecté\n")

print("🔍 Récupération des véhicules...")
vehicles_response = requests.get(API_VEHICLES, headers={"Authorization": f"Bearer {token}"})
vehicles = vehicles_response.json()

print(f"Nombre de véhicules : {len(vehicles)}\n")
print("=" * 80)

for v in vehicles:
    print(f"ID: {v.get('id_vehicule')}")
    print(f"Nom: {v.get('nom')}")
    print(f"Immatriculation: {v.get('immatriculation')}")
    print(f"DevEUI: {v.get('deveui')}")
    print(f"GPS ID: {v.get('id_dispositif_gps')}")
    print("-" * 80)

# Chercher le véhicule avec DevEUI spécifique
target = None
for v in vehicles:
    if v.get('deveui') == '71F118B4E8F86E22':
        target = v
        break

if target:
    print("\n✅ VÉHICULE TROUVÉ avec DevEUI 71F118B4E8F86E22:")
    print(f"   ID: {target.get('id_vehicule')}")
    print(f"   Nom: {target.get('nom')}")
    print(f"   GPS ID: {target.get('id_dispositif_gps')}")
else:
    print("\n❌ Aucun véhicule avec DevEUI 71F118B4E8F86E22")
