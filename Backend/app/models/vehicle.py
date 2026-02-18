from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.db.session import Base
from app.models.user import User

class VehicleStatus(str, enum.Enum):
    ACTIF = "ACTIF"
    INACTIF = "INACTIF"
    MAINTENANCE = "MAINTENANCE"
    SUSPENDU = "SUSPENDU"

class Vehicle(Base):
    __tablename__ = "vehicule"

    id_vehicule = Column(Integer, primary_key=True, index=True)
    nom = Column(String(100), nullable=False)
    immatriculation = Column(String(50), unique=True)
    marque = Column(String(50))
    modele = Column(String(50))
    annee = Column(Integer)
    deveui = Column(String(50), unique=True, nullable=False, index=True)
    statut = Column(String(20), default=VehicleStatus.ACTIF.value)
    moteur_coupe = Column(Boolean, default=False)
    derniere_position_lat = Column(Numeric(10, 8))
    derniere_position_lon = Column(Numeric(11, 8))
    derniere_communication = Column(DateTime)
    id_utilisateur_proprietaire = Column(Integer, ForeignKey("utilisateur.id_utilisateur"))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    proprietaire = relationship("User", back_populates="vehicules")
    zones = relationship("Zone", back_populates="vehicule")
    positions = relationship("Position", back_populates="vehicule")
    alertes = relationship("Alert", back_populates="vehicule")
