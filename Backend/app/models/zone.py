from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Text, JSON
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.session import Base
from app.models.vehicle import Vehicle

class Zone(Base):
    __tablename__ = "zone_securisee"

    id_zone = Column(Integer, primary_key=True, index=True)
    nom = Column(String(100), nullable=False)
    description = Column(Text)
    latitude_centre = Column(Numeric(10, 8), nullable=False)
    longitude_centre = Column(Numeric(11, 8), nullable=False)
    rayon_metres = Column(Integer, nullable=False)
    couleur = Column(String(20), default="#00FF00")
    active = Column(Boolean, default=True)
    type = Column(String(20), default="CIRCLE")
    coordinates = Column(JSON, nullable=True) # List of {lat: float, lng: float}
    id_vehicule = Column(Integer, ForeignKey("vehicule.id_vehicule"))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    vehicule = relationship("Vehicle", back_populates="zones")
