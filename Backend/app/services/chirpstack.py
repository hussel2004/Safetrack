import base64
import struct
import httpx
import logging
from typing import List, Dict, Any
from app.core.config import settings

logger = logging.getLogger(__name__)

def encode_geofence(zone_data: Dict[str, Any]) -> str:
    """
    Encode geofence data into a binary format and return as Base64.
    
    Format for POLYGON (Type 0x02):
    [TYPE: 1 byte][NUM_POINTS: 1 byte][LAT1: 4 bytes float][LON1: 4 bytes float]...
    
    Format for CIRCLE (Type 0x01):
    [TYPE: 1 byte][LAT: 4 bytes float][LON: 4 bytes float][RADIUS: 4 bytes float]
    """
    zone_type = zone_data.get("type", "CIRCLE")
    
    if zone_type == "POLYGON":
        coords = zone_data.get("coordinates", [])
        # If coords is empty, we still send the packet with 0 points to clear the zone
            
        # Type 0x02
        payload = struct.pack(">B", 0x02)
        # Num points
        payload += struct.pack(">B", len(coords))
        
        for point in coords:
            lat = float(point.get("lat", 0.0))
            lon = float(point.get("lng", 0.0)) # usage of lng to match common frontend maps
            payload += struct.pack(">ff", lat, lon)
            
    else:
        # Default to CIRCLE
        lat = float(zone_data.get("latitude_centre", 0.0))
        lon = float(zone_data.get("longitude_centre", 0.0))
        radius = float(zone_data.get("rayon_metres", 0))
        
        # Type 0x01
        payload = struct.pack(">BffH", 0x01, lat, lon, int(radius)) # H for unsigned short (0-65535 meters)

    return base64.b64encode(payload).decode("utf-8")

# ── ChirpStack constants ──────────────────────────────────────────────────
CHIRPSTACK_APPLICATION_ID = "1"
CHIRPSTACK_DEVICE_PROFILE_ID = "528c426f-fa35-4ca2-a4a3-47df89a5a9c5"

async def register_device_in_chirpstack(
    dev_eui: str,
    name: str,
    description: str = "",
) -> bool:
    """
    Register a LoRaWAN device in ChirpStack under the SafeTrack application.
    Uses the fixed gps-tracker-profile and local network server.
    Returns True on success, False on failure (non-blocking).
    """
    if not settings.CHIRPSTACK_API_KEY:
        logger.warning("ChirpStack API Key not set. Skipping device registration.")
        return False

    url = f"{settings.CHIRPSTACK_API_URL}/api/devices"
    headers = {
        "Content-Type": "application/json",
        "Grpc-Metadata-Authorization": f"Bearer {settings.CHIRPSTACK_API_KEY}",
    }
    payload = {
        "device": {
            "devEUI": dev_eui,
            "name": name or dev_eui,
            "description": description or "",
            "applicationID": CHIRPSTACK_APPLICATION_ID,
            "deviceProfileID": CHIRPSTACK_DEVICE_PROFILE_ID,
            "skipFCntCheck": False,
            "isDisabled": False,
        }
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=10.0)
            if response.status_code in (200, 201):
                logger.info(f"Device {dev_eui} registered in ChirpStack (name='{name}').")
                return True
            else:
                logger.warning(
                    f"ChirpStack rejected device registration for {dev_eui}: "
                    f"{response.status_code} {response.text}"
                )
                return False
        except Exception as e:
            logger.warning(f"Failed to register device {dev_eui} in ChirpStack: {e}")
            return False


async def delete_device_from_chirpstack(dev_eui: str) -> bool:
    """
    Delete a device from ChirpStack by its DevEUI.
    Returns True on success, False on failure (non-blocking).
    """
    if not settings.CHIRPSTACK_API_KEY:
        logger.warning("ChirpStack API Key not set. Skipping device deletion.")
        return False

    url = f"{settings.CHIRPSTACK_API_URL}/api/devices/{dev_eui.lower()}"
    headers = {
        "Content-Type": "application/json",
        "Grpc-Metadata-Authorization": f"Bearer {settings.CHIRPSTACK_API_KEY}",
    }

    async with httpx.AsyncClient() as client:
        try:
            response = await client.delete(url, headers=headers, timeout=10.0)
            if response.status_code in (200, 204):
                logger.info(f"Device {dev_eui} deleted from ChirpStack.")
                return True
            elif response.status_code == 404:
                logger.info(f"Device {dev_eui} not found in ChirpStack (already removed or never registered).")
                return True  # considéré OK
            else:
                logger.warning(
                    f"ChirpStack rejected device deletion for {dev_eui}: "
                    f"{response.status_code} {response.text}"
                )
                return False
        except Exception as e:
            logger.warning(f"Failed to delete device {dev_eui} from ChirpStack: {e}")
            return False


async def send_downlink(dev_eui: str, data: str, f_port: int = 10):
    """
    Send a downlink message to a device via ChirpStack API.
    """
    if not settings.CHIRPSTACK_API_KEY:
        logger.warning("ChirpStack API Key not set. Skipping downlink.")
        return

    url = f"{settings.CHIRPSTACK_API_URL}/api/devices/{dev_eui.lower()}/queue"
    
    headers = {
        "Content-Type": "application/json",
        "Grpc-Metadata-Authorization": f"Bearer {settings.CHIRPSTACK_API_KEY}"
    }
    
    payload = {
        "deviceQueueItem": {
            "confirmed": False,
            "fPort": f_port,
            "data": data
        }
    }
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(url, json=payload, headers=headers, timeout=5.0)
            response.raise_for_status()
            resp_data = response.json()
            logger.info(f"Downlink sent to {dev_eui}. Response: {resp_data}")
        except Exception as e:
            logger.error(f"Failed to send downlink to {dev_eui}: {str(e)}")

async def send_command(dev_eui: str, command_text: str, f_port: int = 10):
    """
    Send a text command (converted to Base64) to a device.
    """
    # Mimic: echo "TEXT" | base64
    encoded_data = base64.b64encode(command_text.encode("utf-8")).decode("utf-8")
    await send_downlink(dev_eui, encoded_data, f_port)

async def send_stop_command(dev_eui: str):
    """
    Send STOP command (U1RPUA==) to device.
    """
    await send_command(dev_eui, "STOP")
