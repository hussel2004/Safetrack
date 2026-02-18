from typing import Optional
from pydantic import BaseModel
from datetime import datetime
from app.models.vehicle import VehicleStatus

class VehicleBase(BaseModel):
    nom: str
    immatriculation: Optional[str] = None
    marque: Optional[str] = None
    modele: Optional[str] = None
    annee: Optional[int] = None
    deveui: str
    statut: VehicleStatus = VehicleStatus.ACTIF
    moteur_coupe: bool = False

class VehicleCreate(VehicleBase):
    pass

class VehicleUpdate(BaseModel):
    nom: Optional[str] = None
    immatriculation: Optional[str] = None
    marque: Optional[str] = None
    modele: Optional[str] = None
    annee: Optional[int] = None
    statut: Optional[VehicleStatus] = None
    moteur_coupe: Optional[bool] = None

class VehicleInDBBase(VehicleBase):
    id_vehicule: int
    id_utilisateur_proprietaire: Optional[int] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

class Vehicle(VehicleInDBBase):
    pass
