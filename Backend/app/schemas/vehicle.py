from typing import Optional
from pydantic import BaseModel, field_validator
from datetime import datetime
from app.models.vehicle import VehicleStatus
import re

class VehicleBase(BaseModel):
    nom: Optional[str] = None
    immatriculation: Optional[str] = None
    marque: Optional[str] = None
    modele: Optional[str] = None
    annee: Optional[int] = None
    deveui: str
    statut: VehicleStatus = VehicleStatus.ACTIF
    moteur_coupe: bool = False
    moteur_en_attente: bool = False
    mode_auto: bool = False

class VehicleCreate(VehicleBase):
    pass

# ── Provisioning (Technicien / Admin only) ─────────────────────────────────
class VehicleProvision(BaseModel):
    """Payload pour enregistrer un boîtier depuis le panneau technicien.
    device_name et device_description sont transmis à ChirpStack."""
    deveui: str
    device_name: Optional[str] = None
    device_description: Optional[str] = ""

    @field_validator("deveui")
    @classmethod
    def validate_deveui(cls, v: str) -> str:
        v = v.strip().upper()
        if len(v) != 16 or not re.fullmatch(r"[0-9A-F]{16}", v):
            raise ValueError("DevEUI doit être un hexadécimal de exactement 16 caractères")
        return v

# ── Pairing (Utilisateur final) ────────────────────────────────────────────
class VehiclePair(BaseModel):
    """Payload d'appairage : l'utilisateur revendique un boîtier DISPONIBLE."""
    deveui: str
    nom: str
    marque: Optional[str] = None
    modele: Optional[str] = None
    annee: Optional[int] = None
    immatriculation: Optional[str] = None

    @field_validator("deveui")
    @classmethod
    def validate_deveui(cls, v: str) -> str:
        v = v.strip().upper()
        if len(v) != 16 or not re.fullmatch(r"[0-9A-F]{16}", v):
            raise ValueError("DevEUI doit être un hexadécimal de exactement 16 caractères")
        return v

class VehicleUpdate(BaseModel):
    nom: Optional[str] = None
    immatriculation: Optional[str] = None
    marque: Optional[str] = None
    modele: Optional[str] = None
    annee: Optional[int] = None
    statut: Optional[VehicleStatus] = None
    moteur_coupe: Optional[bool] = None
    moteur_en_attente: Optional[bool] = None
    mode_auto: Optional[bool] = None

class VehicleInDBBase(VehicleBase):
    id_vehicule: int
    id_utilisateur_proprietaire: Optional[int] = None
    created_at: datetime
    activated_at: Optional[datetime] = None
    updated_at: datetime
    moteur_commande_timestamp: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class Vehicle(VehicleInDBBase):
    pass
