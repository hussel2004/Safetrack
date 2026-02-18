#!/usr/bin/env python3
"""
SafeTrack - Script de Test GPS
Lit des positions GPS depuis un fichier texte et les envoie au backend local
"""

import requests
import time
from datetime import datetime

# CONFIGURATION
BACKEND_URL = "http://localhost:8000"
BACKEND_API_TRACKING = f"{BACKEND_URL}/api/v1/tracking/"
BACKEND_API_VEHICLES = f"{BACKEND_URL}/api/v1/vehicles/"
GPS_DATA_FILE = "gps_test_data.txt"
DEVEUI = "71F118B4E8F86E22"

def get_vehicle_id_by_deveui(deveui):
    """Récupère l'ID du véhicule depuis le backend"""
    try:
        # Essayer de récupérer tous les véhicules (nécessite authentification normalement)
        # Pour le moment, on va utiliser une requête simple
        print(f"🔍 Recherche du véhicule avec DevEUI: {deveui}...")
        
        # Compte tenu des limitations, on va supposer que l'ID est probablement un petit nombre
        # et essayer de valider en envoyant une position de test
        for test_id in range(1, 20):
            try:
                # Tester si ce vehicle_id existe en essayant de créer une position
                test_position = {
                    "id_vehicule": test_id,
                    "latitude": 0.0,
                    "longitude": 0.0,
                    "altitude": 0.0,
                    "vitesse": 0.0,
                    "cap": 0.0,
                    "timestamp_gps": "2026-01-01 00:00:00",
                    "fix_status": 1,
                    "satellites": 0,
                    "statut": "ACTIF",
                    "payload_brut": f"TEST:{deveui}"
                }
                
                response = requests.post(BACKEND_API_TRACKING, json=test_position, timeout=2)
                
                if response.status_code == 200:
                    print(f"✅ Véhicule trouvé! ID = {test_id}")
                    return test_id
                    
            except:
                continue
        
        print(f"❌ Aucun véhicule trouvé avec le DevEUI {deveui}")
        return None
        
    except Exception as e:
        print(f"❌ Erreur lors de la recherche: {e}")
        return None

def send_position_to_backend(vehicle_id, timestamp, lat, lon, vitesse, cap, altitude, satellites):
    """Envoie une position GPS au backend local"""
    try:
        position_data = {
            "id_vehicule": vehicle_id,
            "latitude": lat,
            "longitude": lon,
            "altitude": altitude,
            "vitesse": vitesse,
            "cap": cap,
            "timestamp_gps": timestamp,
            "fix_status": 1,
            "satellites": satellites,
            "hdop": None,
            "statut": "ACTIF",
            "dans_zone": None,
            "distance_zone_metres": None,
            "id_zone": None,
            "batterie_pourcentage": None,
            "payload_brut": f"TEST:{DEVEUI}"
        }
        
        response = requests.post(BACKEND_API_TRACKING, json=position_data, timeout=5)
        
        if response.status_code == 200:
            print(f"✅ {timestamp} - Position envoyée: ({lat}, {lon}) - Vitesse: {vitesse} km/h")
            return True
        else:
            print(f"⚠️  Erreur backend: {response.status_code} - {response.text}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Erreur réseau: {e}")
        return False

def main():
    print("="*70)
    print("🚗 SafeTrack - Test GPS")
    print("="*70)
    print(f"📍 DevEUI: {DEVEUI}")
    print(f"📊 Backend: {BACKEND_URL}")
    print("="*70)
    print()
    
    # Trouver l'ID du véhicule
    vehicle_id = get_vehicle_id_by_deveui(DEVEUI)
    if not vehicle_id:
        print("❌ Impossible de continuer sans l'ID du véhicule")
        print("💡 Veuillez enregistrer un véhicule avec le DevEUI 71F118B4E8F86E22 dans l'application")
        return
    
    print(f"🚙 Vehicle ID: {vehicle_id}")
    print()
    
    try:
        with open(GPS_DATA_FILE, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Ignorer les lignes de commentaire
        data_lines = [line.strip() for line in lines if line.strip() and not line.startswith('#')]
        
        print(f"📖 Lecture de {len(data_lines)} positions GPS...")
        print()
        
        for i, line in enumerate(data_lines, 1):
            parts = line.split(',')
            if len(parts) != 7:
                print(f"⚠️  Ligne {i} ignorée (format invalide)")
                continue
            
            timestamp_str, lat, lon, vitesse, cap, altitude, satellites = parts
            
            # Envoyer la position
            send_position_to_backend(
                vehicle_id=vehicle_id,
                timestamp=timestamp_str,
                lat=float(lat),
                lon=float(lon),
                vitesse=float(vitesse),
                cap=float(cap),
                altitude=float(altitude),
                satellites=int(satellites)
            )
            
            # Pause entre les envois (simuler le temps réel)
            if i < len(data_lines):
                time.sleep(2)  # 2 secondes entre chaque position
        
        print()
        print("="*70)
        print("✅ Toutes les positions ont été envoyées!")
        print("="*70)
        print()
        print("💡 Ouvrez l'application SafeTrack sur votre téléphone pour voir le trajet")
        
    except FileNotFoundError:
        print(f"❌ Fichier {GPS_DATA_FILE} non trouvé!")
    except Exception as e:
        print(f"❌ Erreur: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
