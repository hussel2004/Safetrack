from typing import Optional, List, Dict
from pydantic import BaseModel
from datetime import datetime

class ZoneBase(BaseModel):
    nom: str
    description: Optional[str] = None
    latitude_centre: float
    longitude_centre: float
    rayon_metres: int
    couleur: Optional[str] = "#00FF00"
    active: bool = True
    type: Optional[str] = "CIRCLE"
    coordinates: Optional[List[Dict[str, float]]] = None
    id_vehicule: Optional[int] = None

class ZoneCreate(ZoneBase):
    pass

class ZoneUpdate(BaseModel):
    nom: Optional[str] = None
    description: Optional[str] = None
    latitude_centre: Optional[float] = None
    longitude_centre: Optional[float] = None
    rayon_metres: Optional[int] = None
    couleur: Optional[str] = None
    active: Optional[bool] = None
    type: Optional[str] = None
    coordinates: Optional[List[Dict[str, float]]] = None
    id_vehicule: Optional[int] = None

class ZoneInDBBase(ZoneBase):
    id_zone: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class Zone(ZoneInDBBase):
    pass
