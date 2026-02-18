from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.models.user import User
from app.models.vehicle import Vehicle
from app.schemas import vehicle as schemas

from app.services.chirpstack import send_stop_command, send_command
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

@router.get("/", response_model=List[schemas.Vehicle])
async def read_vehicles(
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """
    Retrieve vehicles.
    """
    if current_user.role == "ADMIN":
        result = await db.execute(select(Vehicle).offset(skip).limit(limit))
        vehicles = result.scalars().all()
    else:
        result = await db.execute(
            select(Vehicle)
            .where(Vehicle.id_utilisateur_proprietaire == current_user.id_utilisateur)
            .offset(skip)
            .limit(limit)
        )
        vehicles = result.scalars().all()
    return vehicles

@router.post("/", response_model=schemas.Vehicle)
async def create_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    vehicle_in: schemas.VehicleCreate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Create new vehicle.
    """
    try:
        vehicle = Vehicle(
            **vehicle_in.model_dump(),
            id_utilisateur_proprietaire=current_user.id_utilisateur
        )
        db.add(vehicle)
        await db.commit()
        await db.refresh(vehicle)
        return vehicle
    except Exception as e:
        await db.rollback()
        # Handle duplicate DevEUI error
        if "duplicate key value violates unique constraint" in str(e):
            if "vehicule_deveui_key" in str(e):
                raise HTTPException(
                    status_code=400,
                    detail=f"DevEUI invalide (doit être un hexadécimal de 16 caractères)"
                )
            elif "vehicule_immatriculation_key" in str(e):
                raise HTTPException(
                    status_code=400,
                    detail=f"Immatriculation déjà utilisée"
                )
        # Re-raise other errors
        raise HTTPException(status_code=500, detail=f"Erreur lors de la création du véhicule")

@router.put("/{id}", response_model=schemas.Vehicle)
async def update_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    vehicle_in: schemas.VehicleUpdate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Update a vehicle.
    """
    result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == id))
    vehicle = result.scalars().first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
        raise HTTPException(status_code=400, detail="Not enough permissions")
    
    # Check if moteur_coupe is changing
    moteur_changed = vehicle_in.moteur_coupe is not None and vehicle_in.moteur_coupe != vehicle.moteur_coupe
    
    update_data = vehicle_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(vehicle, field, value)
        
    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)

    # Trigger ChirpStack downlink if moteur_coupe changed
    if moteur_changed and vehicle.deveui:
        try:
            if vehicle.moteur_coupe:
                logger.info(f"Sending STOP command to {vehicle.deveui}")
                await send_stop_command(vehicle.deveui)
            else:
                logger.info(f"Sending START command to {vehicle.deveui}")
                await send_command(vehicle.deveui, "START")
        except Exception as e:
            logger.error(f"Failed to trigger vehicle control downlink: {e}")

    return vehicle

@router.delete("/{id}", response_model=schemas.Vehicle)
async def delete_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Delete a vehicle.
    """
    result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == id))
    vehicle = result.scalars().first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
        raise HTTPException(status_code=400, detail="Not enough permissions")
        
    await db.delete(vehicle)
    await db.commit()
    return vehicle
