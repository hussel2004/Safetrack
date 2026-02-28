from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app import models, schemas
from app.api import deps
from app.services.notification_service import manager
from datetime import datetime
from pydantic import BaseModel

router = APIRouter()

# Schema for Alert creation (should ideally be in app/schemas)
class AlertCreate(BaseModel):
    id_vehicule: int
    type_alerte: str
    severite: str = "MOYENNE"
    message: str
    details_json: Optional[str] = None

class AlertOut(BaseModel):
    id_alerte: int
    id_vehicule: int
    type_alerte: str
    severite: str
    message: str
    created_at: datetime
    acquittee: bool

    class Config:
        orm_mode = True

@router.get("/", response_model=List[AlertOut])
async def read_alerts(
    db: AsyncSession = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: models.User = Depends(deps.get_current_active_user),
):
    """
    Retrieve alerts for the current user's vehicles.
    """
    # Get vehicles for user
    result = await db.execute(
        select(models.Vehicle).where(models.Vehicle.id_utilisateur_proprietaire == current_user.id_utilisateur)
    )
    vehicles = result.scalars().all()
    vehicle_ids = [v.id_vehicule for v in vehicles]
    
    if not vehicle_ids:
        return []

    result = await db.execute(
        select(models.Alert)
        .where(models.Alert.id_vehicule.in_(vehicle_ids))
        .order_by(models.Alert.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    alerts = result.scalars().all()
    return alerts

@router.post("/", response_model=AlertOut)
async def create_alert(
    alert_in: AlertCreate,
    db: AsyncSession = Depends(deps.get_db),
    current_user: models.User = Depends(deps.get_current_active_user),
):
    """
    Create a new alert and broadcast it via WebSocket.
    """
    # Verify vehicle belongs to user
    result = await db.execute(
        select(models.Vehicle).where(models.Vehicle.id_vehicule == alert_in.id_vehicule)
    )
    vehicle = result.scalars().first()
    
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    # In a real scenario, the device/system sending the alert might not be the user owner directly,
    # but for this demo, we assume the authorized user (app) reports it.
    
    # Create Alert
    db_alert = models.Alert(
        id_vehicule=alert_in.id_vehicule,
        type_alerte=alert_in.type_alerte,
        severite=alert_in.severite,
        message=alert_in.message,
        details_json=alert_in.details_json,
        created_at=datetime.utcnow(),
        acquittee=False
    )
    db.add(db_alert)
    await db.commit()
    await db.refresh(db_alert)

    # Broadcast via WebSocket
    message_data = {
        "type": "NEW_ALERT",
        "data": {
            "id": db_alert.id_alerte,
            "vehicle_id": db_alert.id_vehicule,
            "message": db_alert.message,
            "severity": db_alert.severite,
            "timestamp": db_alert.created_at.isoformat()
        }
    }
    
    # Send to the owner of the vehicle
    if vehicle.id_utilisateur_proprietaire:
         await manager.send_personal_message(message_data, vehicle.id_utilisateur_proprietaire)

    return db_alert

@router.put("/{alert_id}/acknowledge", response_model=AlertOut)
async def acknowledge_alert(
    alert_id: int,
    db: AsyncSession = Depends(deps.get_db),
    current_user: models.User = Depends(deps.get_current_active_user),
):
    """
    Acknowledge an alert (mark as read).
    """
    result = await db.execute(select(models.Alert).where(models.Alert.id_alerte == alert_id))
    alert = result.scalars().first()

    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
    
    # Verify vehicle ownership
    result = await db.execute(select(models.Vehicle).where(models.Vehicle.id_vehicule == alert.id_vehicule))
    vehicle = result.scalars().first()

    if not vehicle or vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
        raise HTTPException(status_code=403, detail="Not authorized to acknowledge this alert")

    alert.acquittee = True
    await db.commit()
    await db.refresh(alert)
    return alert
