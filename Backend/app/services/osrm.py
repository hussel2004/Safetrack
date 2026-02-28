import os
import httpx
import logging
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

OSRM_NEAREST_URL = os.getenv("OSRM_URL", "http://router.project-osrm.org/nearest/v1/driving")

async def snap_to_road(lat: float, lon: float) -> Tuple[float, float]:
    """
    Given a raw GPS coordinate (lat, lon), use OSRM to find the nearest road coordinate.
    Returns (snapped_lat, snapped_lon). If OSRM fails, returns the original coordinates.
    """
    url = f"{OSRM_NEAREST_URL}/{lon},{lat}?number=1"
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, timeout=2.0)
            if response.status_code == 200:
                data = response.json()
                if data.get("code") == "Ok" and data.get("waypoints"):
                    snapped_lon, snapped_lat = data["waypoints"][0]["location"]
                    logger.debug(f"OSRM Snap: ({lat}, {lon}) -> ({snapped_lat}, {snapped_lon})")
                    return snapped_lat, snapped_lon
            
            logger.warning(f"OSRM nearest failed with status {response.status_code}: {response.text}")
        except Exception as e:
            logger.error(f"OSRM snap error: {e}")
            
    return lat, lon
