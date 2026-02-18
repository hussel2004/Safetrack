from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.models.user import User
from app.models.vehicle import Vehicle
from app.models.position import Position
from app.schemas import position as schemas

router = APIRouter()

@router.get("/{vehicle_id}", response_model=List[schemas.Position])
async def read_positions(
    *,
    db: AsyncSession = Depends(deps.get_db),
    vehicle_id: int,
    current_user: User = Depends(deps.get_current_active_user),
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """
    Retrieve positions for a vehicle.
    """
    # Check permissions
    result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == vehicle_id))
    vehicle = result.scalars().first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
        
    if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
        raise HTTPException(status_code=400, detail="Not enough permissions")

    result = await db.execute(
        select(Position)
        .where(Position.id_vehicule == vehicle_id)
        .order_by(Position.timestamp_gps.desc())
        .offset(skip)
        .limit(limit)
    )
    positions = result.scalars().all()
    return positions

@router.post("/", response_model=schemas.Position)
async def create_position(
    *,
    db: AsyncSession = Depends(deps.get_db),
    position_in: schemas.PositionCreate,
) -> Any:
    """
    Create new position (Ingestion).
    """
    # Verify vehicle exists
    result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == position_in.id_vehicule))
    vehicle = result.scalars().first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    position = Position(**position_in.model_dump())
    db.add(position)
    await db.commit()
    await db.refresh(position)
    
    # Note: Triggers in SQL will handle update of vehicle last position and alert generation
    
    return position
