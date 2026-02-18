from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.db.session import Base

class AlertType(str, enum.Enum):
    HORS_ZONE = "HORS_ZONE"
    VITESSE_EXCESSIVE = "VITESSE_EXCESSIVE"
    ARRET_PROLONGE = "ARRET_PROLONGE"
    MOTEUR_COUPE = "MOTEUR_COUPE"
    BATTERIE_FAIBLE = "BATTERIE_FAIBLE"

class AlertSeverity(str, enum.Enum):
    FAIBLE = "FAIBLE"
    MOYENNE = "MOYENNE"
    CRITIQUE = "CRITIQUE"

class Alert(Base):
    __tablename__ = "alerte"

    id_alerte = Column(Integer, primary_key=True, index=True)
    id_vehicule = Column(Integer, ForeignKey("vehicule.id_vehicule"), nullable=False)
    id_position = Column(Integer, ForeignKey("position_gps.id_position"))
    type_alerte = Column(String(50), nullable=False, index=True)
    severite = Column(String(20), default=AlertSeverity.MOYENNE.value)
    message = Column(Text, nullable=False)
    details_json = Column(Text)
    action_prise = Column(String(100))
    acquittee = Column(Boolean, default=False, index=True)
    acquittee_par = Column(Integer, ForeignKey("utilisateur.id_utilisateur"))
    acquittee_at = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    vehicule = relationship("Vehicle", back_populates="alertes")
