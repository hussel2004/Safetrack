import logging
import math
from typing import List, Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.vehicle import Vehicle
from app.models.zone import Zone
from app.models.alert import Alert
from app.services.chirpstack import send_stop_command
from app.services.notification_service import manager
from datetime import datetime

logger = logging.getLogger(__name__)

def is_point_in_polygon(lat: float, lon: float, coordinates: List[Dict[str, float]]) -> bool:
    """
    Ray Casting algorithm to check if a point (lat, lon) is inside a polygon.
    coordinates: List of {'lat': float, 'lng': float}
    """
    if not coordinates or len(coordinates) < 3:
        return True  # If no valid polygon, consider it "inside" (safety default)

    inside = False
    j = len(coordinates) - 1
    
    for i in range(len(coordinates)):
        xi, yi = coordinates[i]['lng'], coordinates[i]['lat']
        xj, yj = coordinates[j]['lng'], coordinates[j]['lat']
        
        intersect = ((yi > lat) != (yj > lat)) and \
                    (yj != yi) and \
                    (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi)
        
        if intersect:
            inside = not inside
        j = i
        
    return inside

def is_point_in_circle(lat: float, lon: float, center_lat: float, center_lon: float, radius_m: float) -> bool:
    """
    Check if a point is within a circle using Haversine distance.
    """
    # Earth radius in meters
    R = 6371000.0
    
    phi1, phi2 = math.radians(lat), math.radians(center_lat)
    dphi = math.radians(center_lat - lat)
    dlambda = math.radians(center_lon - lon)
    
    a = math.sin(dphi / 2)**2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2)**2
    
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance = R * c
    
    return distance <= radius_m

async def check_and_enforce_geofence(
    vehicle: Vehicle, 
    lat: float, 
    lon: float, 
    db: AsyncSession
) -> Optional[bool]:
    """
    Main logic for backend-side geofencing.
    Returns:
        True if inside, False if outside, None if no zone/mode_auto disabled.
    """
    if not vehicle.mode_auto:
        return None

    # Get active zone for this vehicle
    result = await db.execute(
        select(Zone).where(Zone.id_vehicule == vehicle.id_vehicule, Zone.active == True)
    )
    zone = result.scalars().first()
    
    if not zone:
        return None

    is_inside = True
    if zone.type == "POLYGON":
        is_inside = is_point_in_polygon(lat, lon, zone.coordinates or [])
    else:
        # Default to CIRCLE
        is_inside = is_point_in_circle(
            lat, lon, 
            float(zone.latitude_centre), 
            float(zone.longitude_centre), 
            float(zone.rayon_metres)
        )

    if not is_inside and not vehicle.moteur_coupe:
        logger.warning(f"[GEOFENCE] Breach detected for vehicle {vehicle.deveui} at {lat}, {lon}")
        
        # 1. Trigger STOP downlink
        await send_stop_command(vehicle.deveui)
        
        # 2. Update vehicle state to PENDING confirmation
        vehicle.moteur_en_attente = True
        vehicle.moteur_commande_timestamp = datetime.utcnow()
        db.add(vehicle)
        
        # 3. Create Alert for Geofence Breach and Engine Stop Request
        alert = Alert(
            id_vehicule=vehicle.id_vehicule,
            type_alerte="HORS_ZONE",
            severite="CRITIQUE",
            message=f"Alerte : Sortie de zone détectée à {lat}, {lon}. Demande d'arrêt du relais envoyée au boîtier.",
            details_json=f'{{"latitude": {lat}, "longitude": {lon}, "id_zone": {zone.id_zone}}}',
            created_at=datetime.utcnow(),
            acquittee=False
        )
        db.add(alert)
        await db.commit()
        await db.refresh(alert)
        
        # 4. Broadcast via WebSocket
        message_data = {
            "type": "NEW_ALERT",
            "data": {
                "id": alert.id_alerte,
                "vehicle_id": alert.id_vehicule,
                "message": alert.message,
                "severity": alert.severite,
                "timestamp": alert.created_at.isoformat()
            }
        }
        if vehicle.id_utilisateur_proprietaire:
            await manager.send_personal_message(message_data, vehicle.id_utilisateur_proprietaire)
            
    return is_inside
