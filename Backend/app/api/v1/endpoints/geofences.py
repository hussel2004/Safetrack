from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.models.user import User
from app.models.zone import Zone
from app.models.vehicle import Vehicle
from app.models.vehicle import Vehicle
from app.schemas import zone as schemas
from app.services.chirpstack import send_downlink
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

@router.get("/", response_model=List[schemas.Zone])
async def read_zones(
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
    skip: int = 0,
    limit: int = 100,
    vehicle_id: int = None,
) -> Any:
    """
    Retrieve zones. Can filter by vehicle_id.
    """
    query = select(Zone)
    
    if vehicle_id:
        query = query.where(Zone.id_vehicule == vehicle_id)
        
    if current_user.role != "ADMIN" and not vehicle_id:
        # If not admin and no specific vehicle requested, show only zones linked to user's vehicles
        # This is a bit complex in pure SQL, simpler to require vehicle_id or show all public zones (id_vehicule IS NULL)
        # For now, let's keep it simple: show all zones user has access to (owned vehicles or shared zones)
         query = query.join(Vehicle, Zone.id_vehicule == Vehicle.id_vehicule, isouter=True) \
                      .where((Vehicle.id_utilisateur_proprietaire == current_user.id_utilisateur) | (Zone.id_vehicule == None))
    
    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    zones = result.scalars().all()
    return zones

@router.post("/", response_model=schemas.Zone)
async def create_zone(
    *,
    db: AsyncSession = Depends(deps.get_db),
    zone_in: schemas.ZoneCreate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Create new zone.
    """
    # Verify vehicle ownership if linked to a vehicle
    if zone_in.id_vehicule:
        result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == zone_in.id_vehicule))
        vehicle = result.scalars().first()
        if not vehicle:
             raise HTTPException(status_code=404, detail="Vehicle not found")
        if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
             raise HTTPException(status_code=400, detail="Not enough permissions")

    # If creating an active zone for a vehicle, deactivate others
    if zone_in.id_vehicule and zone_in.active:
        # Find other active zones for this vehicle
        result = await db.execute(
            select(Zone).where(
                Zone.id_vehicule == zone_in.id_vehicule,
                Zone.active == True,
                Zone.id_zone != zone_in.id_zone if hasattr(zone_in, 'id_zone') else True
            )
        )
        existing_active_zones = result.scalars().all()
        for active_zone in existing_active_zones:
            active_zone.active = False
            db.add(active_zone)
            # Note: We don't need to send a clear downlink for these because the new zone's downlink will overwrite them
        
        if existing_active_zones:
             logger.info(f"Deactivated {len(existing_active_zones)} other zones for vehicle {zone_in.id_vehicule}")

    zone = Zone(**zone_in.model_dump())
    db.add(zone)
    await db.commit()
    await db.refresh(zone)

    # Trigger downlink if linked to vehicle AND active
    # MOVED TO BACKEND: We no longer send zone coordinates to device
    # if zone.id_vehicule and zone.active:
    #     try:
    #         result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == zone.id_vehicule))
    #         vehicle = result.scalars().first()
    #         if vehicle and vehicle.deveui:
    #              encoded_data = encode_geofence(zone_in.model_dump())
    #              if encoded_data:
    #                  await send_downlink(vehicle.deveui, encoded_data)
    #     except Exception as e:
    #         logger.error(f"Failed to trigger downlink for zone {zone.id_zone}: {e}")

    return zone

@router.put("/{id}", response_model=schemas.Zone)
async def update_zone(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    zone_in: schemas.ZoneUpdate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Update a zone.
    """
    result = await db.execute(select(Zone).where(Zone.id_zone == id))
    zone = result.scalars().first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")
        
    # Check permissions
    if zone.id_vehicule:
        result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == zone.id_vehicule))
        vehicle = result.scalars().first()
        if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
             raise HTTPException(status_code=400, detail="Not enough permissions")
    elif current_user.role != "ADMIN":
         # Only admins can edit shared zones
         raise HTTPException(status_code=400, detail="Not enough permissions")

    # Capture old state
    was_active = zone.active

    update_data = zone_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(zone, field, value)
    
    # If updated to be active, deactivate others
    if zone.active and zone.id_vehicule:
         result = await db.execute(
            select(Zone).where(
                Zone.id_vehicule == zone.id_vehicule,
                Zone.active == True,
                Zone.id_zone != zone.id_zone
            )
         )
         other_active_zones = result.scalars().all()
         for other_zone in other_active_zones:
             other_zone.active = False
             db.add(other_zone)
             logger.info(f"Deactivated sibling zone {other_zone.id_zone} because zone {zone.id_zone} became active")

    db.add(zone)
    await db.commit()
    await db.refresh(zone)

    # Trigger downlink logic
    # MOVED TO BACKEND: We no longer sync zone coordinates to vehicle
    # if zone.id_vehicule:
    #     try:
    #          ... (removed)
    #     except Exception as e:
    #         logger.error(f"Failed to trigger downlink for zone {zone.id_zone}: {e}")

    return zone

@router.delete("/{id}", response_model=schemas.Zone)
async def delete_zone(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Delete a zone.
    """
    result = await db.execute(select(Zone).where(Zone.id_zone == id))
    zone = result.scalars().first()
    if not zone:
        raise HTTPException(status_code=404, detail="Zone not found")
        
    # Check permissions
    if zone.id_vehicule:
        result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == zone.id_vehicule))
        vehicle = result.scalars().first()
        if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
             raise HTTPException(status_code=400, detail="Not enough permissions")
    elif current_user.role != "ADMIN":
         raise HTTPException(status_code=400, detail="Not enough permissions")
         
    # Trigger downlink to clear zone on device ONLY if it was active
    # MOVED TO BACKEND: No need to clear local geofence as it's not used anymore
    # if zone.id_vehicule and zone.active:
    #     ... (removed)

    await db.delete(zone)
    await db.commit()
    return zone
