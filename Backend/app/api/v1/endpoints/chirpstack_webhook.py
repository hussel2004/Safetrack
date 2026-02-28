"""
ChirpStack v3 HTTP Integration Webhook
Receives uplink messages from ChirpStack and writes positions to the DB.
Endpoint: POST /api/v1/chirpstack/uplink  (no auth — called by ChirpStack internally)
"""

import base64
import json
import logging
import os
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.api import deps
from app.models.vehicle import Vehicle
from app.models.position import Position
from app.models.alert import Alert
from app.services.osrm import snap_to_road
from app.services.geofencing_service import check_and_enforce_geofence
from app.services.notification_service import manager
from datetime import datetime

router = APIRouter()
logger = logging.getLogger(__name__)

OSRM_ENABLED = os.getenv("OSRM_ENABLED", "false").lower() == "true"


@router.post("/uplink", status_code=200)
async def chirpstack_uplink(
    payload: dict,
    db: AsyncSession = Depends(deps.get_db),
) -> Any:
    """
    Receive an uplink message from ChirpStack HTTP integration (v3 format).

    ChirpStack sends a JSON body like:
    {
      "deviceInfo": { "devEui": "...", ... },
      "object": { "latitude": ..., "longitude": ..., "speed": ..., ... },
      "fCnt": 125,
      ...
    }
    """
    logger.info(f"Full Payload received: {payload}")
    logger.info(f"ChirpStack uplink received: {payload.get('deviceInfo', {}).get('devEui')}")

    # --- 1. Extract DevEUI ---
    # Try multiple common ChirpStack payload formats
    device_info = payload.get("deviceInfo", {})
    dev_eui = device_info.get("devEui") or payload.get("devEui") or payload.get("devEUI")
    
    if not dev_eui:
        logger.error(f"Failed to find devEui in payload keys: {list(payload.keys())}")
        raise HTTPException(status_code=400, detail="Missing devEui in payload")

    # If DevEUI is Base64 (common in some ChirpStack versions), convert to hex
    logger.info(f"Processing dev_eui: '{dev_eui}' (len={len(dev_eui)})")
    # Base64 for 8 bytes is 11 chars (unpadded) or 12 chars (padded)
    if len(dev_eui) in [11, 12] and not all(c in '0123456789abcdefABCDEF' for c in dev_eui):
        try:
            # Add padding if missing
            padding_needed = (4 - len(dev_eui) % 4) % 4
            to_decode = dev_eui + ("=" * padding_needed)
            decoded = base64.b64decode(to_decode)
            if len(decoded) == 8:
                dev_eui = decoded.hex()
                logger.info(f"Decoded Base64 DevEUI to hex: '{dev_eui}'")
        except Exception as e:
            logger.error(f"Base64 decode failed for '{dev_eui}': {e}")

    # --- 2. Find the corresponding vehicle ---
    result = await db.execute(
        select(Vehicle).where(func.lower(Vehicle.deveui) == dev_eui.lower())
    )
    vehicle = result.scalars().first()
    if not vehicle:
        logger.warning(f"Unknown devEui: {dev_eui}")
        # Return 200 so ChirpStack doesn't retry indefinitely
        return {"status": "ignored", "reason": f"devEui {dev_eui} not registered"}

    # --- 3. Extract GPS data ---
    # Be flexible: check in "object" (standard) or at the top level
    # Support case-insensitive keys (latitude vs Latitude, etc.)
    def get_case_insensitive(d, key):
        if not d: return None
        for k, v in d.items():
            if k.lower() == key.lower():
                return v
        return None

    gps = payload.get("object", {})
    # ChirpStack some versions send data in 'objectJSON' as a string
    object_json_str = payload.get("objectJSON")
    if not gps and object_json_str:
        try:
            gps = json.loads(object_json_str)
            logger.info(f"Parsed GPS from objectJSON: {gps}")
        except Exception as e:
            logger.error(f"Failed to parse objectJSON: {e}")

    lat = get_case_insensitive(gps, "latitude") or get_case_insensitive(payload, "latitude")
    lon = get_case_insensitive(gps, "longitude") or get_case_insensitive(payload, "longitude")

    # --- 3b. Relay confirmation ---
    # Primary: relay_status from decoded object (when ChirpStack codec is configured)
    relay_status = get_case_insensitive(gps, "relay_status")

    # Support relay_cut / relay_active boolean fields sent by the device
    relay_cut_field = get_case_insensitive(gps, "relay_cut")
    relay_active_field = get_case_insensitive(gps, "relay_active")
    if relay_status in (None, "unknown", ""):
        if relay_cut_field is True:
            relay_status = "cut"
        elif relay_active_field is True:
            relay_status = "active"

    logger.info(f"relay_status='{relay_status}' relay_cut={relay_cut_field} relay_active={relay_active_field} moteur_en_attente={vehicle.moteur_en_attente}")

    # Fallback: decode raw bytes from 'data' when objectJSON is empty (no codec configured)
    if relay_status not in ("cut", "active") and lat is None:
        data_b64 = payload.get("data")
        if data_b64:
            try:
                raw_bytes = base64.b64decode(data_b64)
                logger.info(f"Raw LoRa bytes ({len(raw_bytes)} byte(s)): {raw_bytes.hex()}")
                if len(raw_bytes) == 1:
                    relay_status = "cut"
                elif len(raw_bytes) == 2:
                    relay_status = "active"
            except Exception as e:
                logger.error(f"Failed to decode raw data bytes: {e}")

    # Process relay confirmation only when a command is pending OR state changed
    if relay_status in ("cut", "active") and (
        vehicle.moteur_en_attente
        or (relay_status == "cut") != vehicle.moteur_coupe
    ):
        is_cut = relay_status == "cut"
        vehicle.moteur_coupe = is_cut
        vehicle.moteur_en_attente = False
        db.add(vehicle)

        confirmation_alert = Alert(
            id_vehicule=vehicle.id_vehicule,
            type_alerte="MOTEUR_COUPE",
            severite="CRITIQUE" if is_cut else "FAIBLE",
            message=(
                f"Confirmation : Le relais du véhicule {vehicle.immatriculation} "
                f"a été {'coupé' if is_cut else 'rétabli'} avec succès par le boîtier."
            ),
            details_json=json.dumps({
                "action": "relay_cut_confirmed" if is_cut else "relay_active_confirmed",
                "deveui": vehicle.deveui
            }),
            created_at=datetime.utcnow(),
            acquittee=False,
        )
        db.add(confirmation_alert)
        await db.commit()
        await db.refresh(confirmation_alert)

        if vehicle.id_utilisateur_proprietaire:
            # 1. Alert notification
            await manager.send_personal_message({
                "type": "NEW_ALERT",
                "data": {
                    "id": confirmation_alert.id_alerte,
                    "vehicle_id": confirmation_alert.id_vehicule,
                    "message": confirmation_alert.message,
                    "severity": confirmation_alert.severite,
                    "timestamp": confirmation_alert.created_at.isoformat(),
                },
            }, vehicle.id_utilisateur_proprietaire)
            # 2. Vehicle state update — triggers app to refresh vehicle list
            await manager.send_personal_message({
                "type": "VEHICLE_UPDATE",
                "data": {
                    "vehicle_id": vehicle.id_vehicule,
                    "moteur_coupe": is_cut,
                    "moteur_en_attente": False,
                },
            }, vehicle.id_utilisateur_proprietaire)

        action = "relay_cut_confirmed" if is_cut else "relay_active_confirmed"
        logger.info(f"✅ {action} for {dev_eui}")
        return {"status": "ok", "message": action}

    if lat is None or lon is None:
        logger.warning(f"No GPS or relay_status in uplink for devEui {dev_eui}. Keys found: {list(payload.keys())}")
        if gps:
            logger.warning(f"Keys in 'object': {list(gps.keys())}")
        return {"status": "ignored", "reason": "No GPS or relay confirmation data"}

    lat, lon = float(lat), float(lon)
    if OSRM_ENABLED:
        lat, lon = await snap_to_road(lat, lon)

    speed = float(get_case_insensitive(gps, "speed") or get_case_insensitive(payload, "speed") or 0.0)
    heading = float(get_case_insensitive(gps, "heading") or get_case_insensitive(payload, "heading") or 0.0)
    altitude = float(get_case_insensitive(gps, "altitude") or get_case_insensitive(payload, "altitude") or 0.0)
    satellites = int(get_case_insensitive(gps, "satellites") or get_case_insensitive(payload, "satellites") or 0)
    f_cnt = payload.get("fCnt", 0)

    statut = "EN_MOUVEMENT" if speed > 5 else "ARRET"

    timestamp = datetime.utcnow()

    # --- 4. Insert position ---
    position = Position(
        id_vehicule=vehicle.id_vehicule,
        latitude=lat,
        longitude=lon,
        altitude=altitude,
        vitesse=speed,
        cap=heading,
        timestamp_gps=timestamp,
        fix_status=1,
        satellites=satellites,
        hdop=None,
        statut=statut,
        dans_zone=None,
        distance_zone_metres=None,
        id_zone=None,
        batterie_pourcentage=None,
        payload_brut=f"CHIRPSTACK_FCNT_{f_cnt}",
    )
    db.add(position)
    await db.commit()
    await db.refresh(position)

    # --- 4b. Backend Geofencing ---
    is_inside = await check_and_enforce_geofence(vehicle, lat, lon, db)
    if is_inside is not None:
        position.dans_zone = is_inside
        db.add(position)
        await db.commit()

    logger.info(
        f"Position saved: vehicle={vehicle.id_vehicule} "
        f"lat={lat} lon={lon} speed={speed} km/h"
    )

    # --- 5. Update Vehicle Last Status ---
    vehicle.derniere_communication = timestamp
    vehicle.derniere_position_lat = lat
    vehicle.derniere_position_lon = lon
    db.add(vehicle)
    await db.commit()

    return {"status": "ok", "id_position": position.id_position}
