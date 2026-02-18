from typing import Optional
from pydantic import BaseModel
from datetime import datetime

class PositionBase(BaseModel):
    latitude: float
    longitude: float
    altitude: Optional[float] = None
    vitesse: float
    cap: Optional[float] = None
    timestamp_gps: datetime
    fix_status: Optional[int] = None
    satellites: Optional[int] = None
    hdop: Optional[float] = None
    statut: str
    dans_zone: Optional[bool] = None
    distance_zone_metres: Optional[float] = None
    id_zone: Optional[int] = None
    batterie_pourcentage: Optional[int] = None
    payload_brut: Optional[str] = None

class PositionCreate(PositionBase):
    id_vehicule: int

class PositionInDBBase(PositionBase):
    id_position: int
    id_vehicule: int
    created_at: datetime
    
    class Config:
        from_attributes = True

class Position(PositionInDBBase):
    pass
