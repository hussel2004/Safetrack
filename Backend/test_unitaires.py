import unittest
import math
from datetime import datetime

# --- FONCTIONS A TESTER (Simulées ou importées) ---

def calcul_distance_haversine(lat1, lon1, lat2, lon2):
    """
    Calcule la distance en mètres entre deux points GPS.
    """
    R = 6371000  # Rayon de la Terre en mètres
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) * math.sin(dlat / 2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dlon / 2) * math.sin(dlon / 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def est_dans_zone(lat, lon, zone_lat, zone_lon, rayon):
    """
    Vérifie si un point est dans une zone circulaire.
    """
    distance = calcul_distance_haversine(lat, lon, zone_lat, zone_lon)
    return distance <= rayon, distance

def parse_sim808_payload(payload_str):
    """
    Simule le parsing d'une trame CGNSINF.
    Format attendu: run_status,fix_status,date,lat,lon,alt,speed,course,...
    """
    parts = payload_str.split(',')
    if len(parts) < 5:
        return None
    
    # 1,1,20231027120000.000,3.8666,11.5166,...
    try:
        fix_status = int(parts[1])
        if fix_status == 0:
            return {'valid': False, 'error': 'No GPS Fix'}
            
        lat = float(parts[3])
        lon = float(parts[4])
        speed = float(parts[6]) if len(parts) > 6 else 0.0
        
        return {
            'valid': True,
            'lat': lat,
            'lon': lon,
            'speed': speed
        }
    except ValueError:
        return None

# --- CLASSE DE TEST ---

class TestSafeTrackLogic(unittest.TestCase):

    def setUp(self):
        print("\n--- Démarrage du test ---")

    def test_haversine_distance(self):
        """Test du calcul de distance GPS"""
        # Distance entre Pharmacie Emia (3.8619, 11.5117) et Total Melen (3.8690, 11.5030)
        # Distance approx ~ 1.3 km
        lat1, lon1 = 3.8619, 11.5117
        lat2, lon2 = 3.8690, 11.5030
        
        distance = calcul_distance_haversine(lat1, lon1, lat2, lon2)
        print(f"Distance calculée: {distance:.2f} mètres")
        
        # On vérifie que la distance est cohérente (entre 1000m et 1500m)
        self.assertTrue(1000 < distance < 1500)

    def test_detection_geofence(self):
        """Test de la détection de zone (Geofencing)"""
        zone_lat, zone_lon = 3.8666, 11.5166 # Centre Zone
        rayon = 500 # mètres
        
        # Point DANS la zone (à 100m)
        point_in_lat, point_in_lon = 3.8670, 11.5170
        is_in, dist = est_dans_zone(point_in_lat, point_in_lon, zone_lat, zone_lon, rayon)
        print(f"Test Zone IN: Distance={dist:.2f}m -> Dedans? {is_in}")
        self.assertTrue(is_in)
        
        # Point HORS de la zone (à 2km)
        point_out_lat, point_out_lon = 3.8800, 11.5200
        is_in, dist = est_dans_zone(point_out_lat, point_out_lon, zone_lat, zone_lon, rayon)
        print(f"Test Zone OUT: Distance={dist:.2f}m -> Dedans? {is_in}")
        self.assertFalse(is_in)

    def test_parse_payload_valid(self):
        """Test du parsing d'une trame valide"""
        payload = "1,1,20231027120000.000,3.8666,11.5166,100.0,45.5,0,0"
        result = parse_sim808_payload(payload)
        
        print(f"Test Parsing Valide: {result}")
        self.assertIsNotNone(result)
        self.assertTrue(result['valid'])
        self.assertEqual(result['lat'], 3.8666)
        self.assertEqual(result['lon'], 11.5166)

    def test_parse_payload_invalid(self):
        """Test du parsing d'une trame invalide (Fix=0)"""
        payload = "1,0,,,,,,,"
        result = parse_sim808_payload(payload)
        
        print(f"Test Parsing Invalide: {result}")
        self.assertIsNotNone(result)
        self.assertFalse(result['valid'])
        self.assertEqual(result['error'], 'No GPS Fix')

    # --- NOUVEAUX TESTS (Total visé: 12) ---

    def test_haversine_same_point(self):
        """Test distance nulle pour le même point"""
        dist = calcul_distance_haversine(3.86, 11.51, 3.86, 11.51)
        self.assertEqual(dist, 0.0)

    def test_haversine_zero_coords(self):
        """Test distance depuis l'équateur/méridien 0"""
        # Distance (0,0) -> (1,0) = ~111km (1 degré de latitude)
        dist = calcul_distance_haversine(0, 0, 1, 0)
        self.assertAlmostEqual(dist, 111195, delta=500) # Delta tolérant

    def test_detection_geofence_edge_in(self):
        """Test limite EXACTE du rayon (Inclus)"""
        # Centre (0,0), Rayon 100m. Point à ~99m au Nord
        # 0.0009 deg lat ~= 100m
        is_in, dist = est_dans_zone(0.0008, 0, 0, 0, 100) 
        self.assertTrue(is_in, f"Devrait être dans la zone (Dist: {dist})")

    def test_detection_geofence_edge_out(self):
        """Test limite EXACTE du rayon (Exclus)"""
        # Centre (0,0), Rayon 100m. Point à ~111m au Nord (0.001)
        is_in, dist = est_dans_zone(0.0011, 0, 0, 0, 100)
        self.assertFalse(is_in, f"Devrait être hors zone (Dist: {dist})")

    def test_parse_payload_empty(self):
        """Test payload vide"""
        res = parse_sim808_payload("")
        self.assertIsNone(res)

    def test_parse_payload_truncated(self):
        """Test payload tronqué/incomplet"""
        res = parse_sim808_payload("1,1,2023") # Manque suite
        self.assertIsNone(res)

    def test_parse_payload_garbage(self):
        """Test payload avec données corrompues"""
        # Lat/Lon ne sont pas des nombres
        res = parse_sim808_payload("1,1,DATE,NOT_A_NUMBER,XYZ,100,0,0,0")
        self.assertIsNone(res)

    def test_parse_payload_no_speed(self):
        """Test payload valide sans vitesse (comportement par défaut)"""
        # On ne met que 5 champs (jusqu'à lon)
        payload = "1,1,DATE,3.8,11.5" 
        res = parse_sim808_payload(payload)
        self.assertTrue(res['valid'])
        self.assertEqual(res['speed'], 0.0)

if __name__ == '__main__':
    unittest.main(verbosity=2)
