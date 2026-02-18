from sqlalchemy import Column, Integer, String, DateTime, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.db.session import Base

class UserRole(str, enum.Enum):
    ADMIN = "ADMIN"
    GESTIONNAIRE = "GESTIONNAIRE"
    SUPERVISEUR = "SUPERVISEUR"

class UserStatus(str, enum.Enum):
    ACTIF = "ACTIF"
    INACTIF = "INACTIF"
    SUSPENDU = "SUSPENDU"

class User(Base):
    __tablename__ = "utilisateur"

    id_utilisateur = Column(Integer, primary_key=True, index=True)
    nom = Column(String(100), nullable=False)
    prenom = Column(String(100), nullable=False)
    email = Column(String(150), unique=True, index=True, nullable=False)
    telephone = Column(String(20))
    mot_de_passe = Column(String(255), nullable=False)
    role = Column(String(20), default=UserRole.GESTIONNAIRE.value)
    statut = Column(String(20), default=UserStatus.ACTIF.value)
    derniere_connexion = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    vehicules = relationship("Vehicle", back_populates="proprietaire")
