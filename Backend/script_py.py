#!/usr/bin/env python3
"""
SafeTrack - Script Lecture Base de Données
Lit et affiche les données GPS depuis PostgreSQL
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import time
import re
from datetime import datetime

# CONFIGURATION POUR EXÉCUTION DANS DOCKER
DB_CONFIG = {
    "host": "db",  # Nom du service dans docker-compose
    "port": 5432,  # Port interne (pas 5433 qui est le port mappé)
    "database": "safetrack_geofencing",
    "user": "safetrack_user",
    "password": "safetrack_password"
}

def parse_gps_cgnsinf(text_payload):
    """
    Parse une trame GPS au format AT+CGNSINF
    Format: run_status,fix_status,datetime,lat,lon,alt,speed,course,fix_mode,reserved1,hdop,pdop,vdop,reserved2,sat_gps,sat_glonass,reserved3,cn0_max
    
    Exemple: 1,1,20260206233000.000,48.8584,2.2945,150.0,0.0,0.0,1,,,,,12,0,,,
    """
    parts = text_payload.split(',')
    
    # Vérifier qu'on a au moins 9 champs
    if len(parts) < 9:
        return None
    
    try:
        run_status = int(parts[0]) if parts[0] else 0
        fix_status = int(parts[1]) if parts[1] else 0
        
        # Si pas de fix GPS, ne pas parser
        if fix_status != 1:
            return {
                'type': 'CGNSINF',
                'valid': False,
                'message': 'Pas de fix GPS (recherche satellites...)'
            }
        
        datetime_str = parts[2]  # Format: YYYYMMDDHHmmss.sss
        latitude = float(parts[3]) if parts[3] else 0.0
        longitude = float(parts[4]) if parts[4] else 0.0
        altitude = float(parts[5]) if parts[5] else 0.0
        speed = float(parts[6]) if parts[6] else 0.0
        course = float(parts[7]) if parts[7] else 0.0
        fix_mode = int(parts[8]) if parts[8] else 0
        
        # Parser le datetime (YYYYMMDDHHmmss.sss)
        if datetime_str and len(datetime_str) >= 14:
            dt = datetime.strptime(datetime_str[:14], '%Y%m%d%H%M%S')
            horodatage = dt.strftime('%Y-%m-%d %H:%M:%S')
        else:
            horodatage = "N/A"
        
        # Nombre de satellites (champ 14 pour GPS, 15 pour GLONASS)
        sat_gps = int(parts[14]) if len(parts) > 14 and parts[14] else 0
        sat_glonass = int(parts[15]) if len(parts) > 15 and parts[15] else 0
        total_satellites = sat_gps + sat_glonass
        
        return {
            'type': 'CGNSINF',
            'valid': True,
            'horodatage': horodatage,
            'latitude': latitude,
            'longitude': longitude,
            'altitude': altitude,
            'vitesse': speed,
            'cap': course,
            'satellites': total_satellites,
            'sat_gps': sat_gps,
            'sat_glonass': sat_glonass,
            'fix_mode': fix_mode
        }
    
    except (ValueError, IndexError) as e:
        return {
            'type': 'CGNSINF',
            'valid': False,
            'message': f'Erreur parsing: {e}'
        }

def parse_gps_cgpsinf(text_payload):
    """
    Parse une trame GPS au format AT+CGPSINF=32
    Format: mode,hhmmss.sss,lat,N/S,lon,E/W,ddmmyy,alt,speed,course
    
    Exemple: 32,123045.000,4851.5040,N,00213.7670,E,060226,150.0,0.0,0.0
    """
    parts = text_payload.split(',')
    
    if len(parts) < 10:
        return None
    
    try:
        mode = parts[0]
        time_str = parts[1]
        lat_str = parts[2]
        lat_dir = parts[3]  # N or S
        lon_str = parts[4]
        lon_dir = parts[5]  # E or W
        date_str = parts[6]
        altitude = float(parts[7]) if parts[7] else 0.0
        speed = float(parts[8]) if parts[8] else 0.0
        course = float(parts[9]) if parts[9] else 0.0
        
        # Convertir latitude (format: ddmm.mmmm)
        if lat_str:
            lat_deg = int(float(lat_str) / 100)
            lat_min = float(lat_str) - (lat_deg * 100)
            latitude = lat_deg + (lat_min / 60.0)
            if lat_dir == 'S':
                latitude = -latitude
        else:
            latitude = 0.0
        
        # Convertir longitude (format: dddmm.mmmm)
        if lon_str:
            lon_deg = int(float(lon_str) / 100)
            lon_min = float(lon_str) - (lon_deg * 100)
            longitude = lon_deg + (lon_min / 60.0)
            if lon_dir == 'W':
                longitude = -longitude
        else:
            longitude = 0.0
        
        # Parser date et heure
        if date_str and time_str and len(date_str) == 6 and len(time_str) >= 6:
            # ddmmyy + hhmmss
            dt = datetime.strptime(date_str + time_str[:6], '%d%m%y%H%M%S')
            horodatage = dt.strftime('%Y-%m-%d %H:%M:%S')
        else:
            horodatage = "N/A"
        
        return {
            'type': 'CGPSINF',
            'valid': True,
            'horodatage': horodatage,
            'latitude': latitude,
            'longitude': longitude,
            'altitude': altitude,
            'vitesse': speed,
            'cap': course,
            'satellites': 'N/A'  # CGPSINF ne fournit pas cette info
        }
    
    except (ValueError, IndexError) as e:
        return {
            'type': 'CGPSINF',
            'valid': False,
            'message': f'Erreur parsing: {e}'
        }

def afficher_position(data):
    """Affiche une position GPS de manière formatée"""
    print("\n" + "="*70)
    print(f"📍 NOUVELLE POSITION GPS")
    print("="*70)
    
    if data['valid']:
        print(f"⏰ Horodatage    : {data['horodatage']}")
        print(f"🌍 Latitude      : {data['latitude']:.6f}°")
        print(f"🌍 Longitude     : {data['longitude']:.6f}°")
        
        if 'altitude' in data:
            print(f"⛰️  Altitude      : {data['altitude']:.1f} m")
        
        print(f"🚀 Vitesse       : {data['vitesse']:.2f} km/h")
        
        if 'cap' in data:
            print(f"🧭 Cap/Direction : {data['cap']:.1f}°")
        
        if data['satellites'] != 'N/A':
            print(f"🛰️  Satellites    : {data['satellites']}")
            if 'sat_gps' in data:
                print(f"   └─ GPS       : {data['sat_gps']}")
            if 'sat_glonass' in data:
                print(f"   └─ GLONASS   : {data['sat_glonass']}")
        
        print(f"📡 Type trame    : {data['type']}")
    else:
        print(f"⚠️  {data.get('message', 'Données invalides')}")
    
    print("="*70)

def lire_base_donnees():
    """Lit continuellement les données de la base PostgreSQL"""
    
    print("=" * 70)
    print("🗄️  SafeTrack - Lecture Base de Données")
    print("=" * 70)
    print(f"📊 Connexion à : {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    print("=" * 70)
    
    derniere_id = 0
    
    try:
        # Connexion au conteneur PostgreSQL
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        
        print("✅ Connecté à SafeTrack DB (PostgreSQL Docker)\n")
        
        while True:
            # Récupérer TOUS les nouveaux messages uplink non encore affichés
            cur.execute("""
                SELECT 
                    id,
                    dev_eui,
                    text_payload,
                    processed,
                    error_message,
                    created_at
                FROM uplink_messages 
                WHERE id > %s
                ORDER BY id ASC;
            """, (derniere_id,))
            
            messages = cur.fetchall()
            
            if messages:
                for msg in messages:
                    # Mettre à jour le dernier ID traité immédiatement
                    derniere_id = msg['id']
                    
                    # Parser le payload silencieusement
                    if msg['text_payload']:
                        payload = msg['text_payload'].strip()
                        
                        # Essayer de parser comme CGNSINF
                        data = parse_gps_cgnsinf(payload)
                        
                        # Si ça échoue, essayer CGPSINF
                        if not data:
                            data = parse_gps_cgpsinf(payload)
                        
                        # Afficher UNIQUEMENT si c'est une position GPS valide
                        if data and data.get('valid'):
                            print(f"\n📨 Message GPS #{msg['id']} - {msg['created_at'].strftime('%H:%M:%S')}")
                            print(f"   DevEUI: {msg['dev_eui']}")
                            afficher_position(data)
                        # Ignorer tout le reste (tests, commandes, etc.)
            
            # Afficher un point toutes les 5 secondes pour montrer que le script tourne
            if not messages:
                print(".", end="", flush=True)
            
            time.sleep(5)
    
    except psycopg2.OperationalError as e:
        print(f"\n❌ Erreur de connexion à la base de données:")
        print(f"   {e}")
        print(f"\n💡 Vérifiez que le conteneur PostgreSQL est démarré:")
        print(f"   docker ps | grep mypostgres")
    
    except KeyboardInterrupt:
        print("\n\n👋 Arrêt du programme (Ctrl+C)")
    
    except Exception as e:
        print(f"\n⚠️ Erreur inattendue : {e}")
        import traceback
        traceback.print_exc()
    
    finally:
        if 'conn' in locals():
            conn.close()
            print("\n🔌 Connexion fermée")

if __name__ == "__main__":
    lire_base_donnees()