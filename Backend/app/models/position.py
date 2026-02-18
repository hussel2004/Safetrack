from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Numeric, Text, SmallInteger
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.session import Base

class Position(Base):
    __tablename__ = "position_gps"

    id_position = Column(Integer, primary_key=True, index=True)
    id_vehicule = Column(Integer, ForeignKey("vehicule.id_vehicule"), nullable=False)
    latitude = Column(Numeric(10, 8), nullable=False)
    longitude = Column(Numeric(11, 8), nullable=False)
    altitude = Column(Numeric(8, 2))
    vitesse = Column(Numeric(6, 2), nullable=False)
    cap = Column(Numeric(5, 2))
    timestamp_gps = Column(DateTime, nullable=False, index=True)
    fix_status = Column(SmallInteger)
    satellites = Column(Integer)
    hdop = Column(Numeric(4, 2))
    statut = Column(String(20), nullable=False, index=True)
    dans_zone = Column(Boolean, index=True)
    distance_zone_metres = Column(Numeric(10, 2))
    id_zone = Column(Integer, ForeignKey("zone_securisee.id_zone"))
    batterie_pourcentage = Column(Integer)
    payload_brut = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    vehicule = relationship("Vehicle", back_populates="positions")
