from typing import Any, List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.api import deps
from app.models.user import User
from app.models.vehicle import Vehicle, VehicleStatus
from app.schemas import vehicle as schemas

from app.services.chirpstack import send_stop_command, send_command, register_device_in_chirpstack, delete_device_from_chirpstack, send_downlink
from app.models.zone import Zone
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

async def _apply_command_timeouts(vehicles: List[Vehicle], db: AsyncSession):
    """
    Check if any vehicle has a pending command that timed out (> 300s).
    If so, reset the pending flag.
    LoRaWAN round-trip: uplink interval + RX window + 12s Arduino delay → can exceed 60s easily.
    """
    TIMEOUT_SECONDS = 300  # 5 minutes
    now = datetime.utcnow()
    changed = False
    for v in vehicles:
        if v.moteur_en_attente and v.moteur_commande_timestamp:
            ts = v.moteur_commande_timestamp
            # Handle timezone-aware timestamps from DB
            if ts.tzinfo is not None:
                import pytz
                ts = ts.replace(tzinfo=None)  # strip tz for naive comparison
            delta = (now - ts).total_seconds()
            logger.info(f"[Timeout check] {v.deveui}: delta={delta:.1f}s, moteur_en_attente={v.moteur_en_attente}")
            if delta > TIMEOUT_SECONDS:
                logger.warning(f"Timeout ({TIMEOUT_SECONDS}s) for engine command on {v.deveui}. Resetting.")
                v.moteur_en_attente = False
                v.moteur_commande_timestamp = None
                changed = True

                # Create Timeout Alert
                from app.models.alert import Alert
                nom_vehicule = v.immatriculation or v.nom or v.deveui
                timeout_alert = Alert(
                    id_vehicule=v.id_vehicule,
                    type_alerte="MOTEUR_COUPE",
                    severite="CRITIQUE",
                    message=f"Erreur de communication : Le boîtier du véhicule {nom_vehicule} n'a pas répondu à la commande dans les 5 minutes.",
                    details_json=f'{{"action": "command_timeout", "deveui": "{v.deveui}"}}',
                    created_at=datetime.utcnow(),
                    acquittee=False
                )
                db.add(timeout_alert)
                
                try:
                    from app.services.notification_service import manager
                    import asyncio
                    message_data = {
                        "type": "NEW_ALERT",
                        "data": {
                            "id": 0,
                            "vehicle_id": v.id_vehicule,
                            "message": timeout_alert.message,
                            "severity": timeout_alert.severite,
                            "timestamp": timeout_alert.created_at.isoformat()
                        }
                    }
                    if v.id_utilisateur_proprietaire:
                        asyncio.create_task(manager.send_personal_message(message_data, v.id_utilisateur_proprietaire))
                except Exception as e:
                    logger.warning(f"Could not broadcast timeout alert: {e}")
    if changed:
        db.add_all(vehicles)
        await db.commit()
    return vehicles

# ── LIST ──────────────────────────────────────────────────────────────────────

@router.get("/", response_model=List[schemas.Vehicle])
async def read_vehicles(
    db: AsyncSession = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
    skip: int = 0,
    limit: int = 100,
) -> Any:
    """Retrieve vehicles owned by the current user (or all for ADMIN)."""
    if current_user.role == "ADMIN":
        result = await db.execute(select(Vehicle).offset(skip).limit(limit))
    else:
        result = await db.execute(
            select(Vehicle)
            .where(Vehicle.id_utilisateur_proprietaire == current_user.id_utilisateur)
            .offset(skip)
            .limit(limit)
        )
    vehicles = result.scalars().all()
    await _apply_command_timeouts(list(vehicles), db)
    return vehicles

# ── PROVISION (Admin / Technicien only) ──────────────────────────────────────

@router.post("/provision", response_model=schemas.Vehicle, status_code=201)
async def provision_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    vehicle_in: schemas.VehicleProvision,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    [ADMIN ONLY] Pré-enregistrer un boîtier LoRaWAN par son DevEUI.
    Statut = DISPONIBLE, pas d'utilisateur associé.
    """
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")

    # Vérifier doublon DevEUI
    existing = await db.execute(
        select(Vehicle).where(Vehicle.deveui == vehicle_in.deveui)
    )
    if existing.scalars().first():
        raise HTTPException(
            status_code=409,
            detail=f"DevEUI {vehicle_in.deveui} est déjà enregistré dans le système"
        )

    vehicle = Vehicle(
        deveui=vehicle_in.deveui,
        statut=VehicleStatus.DISPONIBLE.value,
        id_utilisateur_proprietaire=None,
        nom=None,
    )
    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)
    logger.info(f"DevEUI provisionné : {vehicle_in.deveui}")

    # ── Register in ChirpStack (non-blocking) ──────────────────────────────
    cs_name = vehicle_in.device_name or vehicle_in.deveui
    cs_desc = vehicle_in.device_description or ""
    try:
        ok = await register_device_in_chirpstack(vehicle_in.deveui, cs_name, cs_desc)
        if ok:
            logger.info(f"Device {vehicle_in.deveui} enregistré dans ChirpStack")
        else:
            logger.warning(f"Device {vehicle_in.deveui} NON enregistré dans ChirpStack (voir logs)")
    except Exception as cs_err:
        logger.warning(f"Erreur ChirpStack pour {vehicle_in.deveui}: {cs_err}")

    return vehicle

# ── PAIR (Utilisateur final) ──────────────────────────────────────────────────

@router.post("/pair", response_model=schemas.Vehicle)
async def pair_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    pair_in: schemas.VehiclePair,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    L'utilisateur revendique un boîtier DISPONIBLE via son DevEUI.
    Règles de sécurité :
      - le DevEUI doit exister avec statut=DISPONIBLE
      - user_id doit être NULL (anti-réutilisation/vol)
    """
    result = await db.execute(
        select(Vehicle).where(Vehicle.deveui == pair_in.deveui)
    )
    vehicle = result.scalars().first()

    if not vehicle:
        raise HTTPException(
            status_code=404,
            detail="DevEUI introuvable. Vérifiez le code sur votre boîtier."
        )
    if vehicle.statut != VehicleStatus.DISPONIBLE.value:
        raise HTTPException(
            status_code=409,
            detail="Ce boîtier est déjà associé à un compte ou n'est pas disponible."
        )
    if vehicle.id_utilisateur_proprietaire is not None:
        raise HTTPException(
            status_code=409,
            detail="Ce boîtier est déjà associé à un autre compte."
        )

    # Appairage
    vehicle.nom = pair_in.nom
    vehicle.marque = pair_in.marque
    vehicle.modele = pair_in.modele
    vehicle.annee = pair_in.annee
    vehicle.immatriculation = pair_in.immatriculation
    vehicle.id_utilisateur_proprietaire = current_user.id_utilisateur
    vehicle.statut = VehicleStatus.ACTIF.value
    vehicle.activated_at = datetime.utcnow()

    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)
    logger.info(
        f"Appairage réussi : DevEUI={vehicle.deveui} → user={current_user.id_utilisateur}"
    )

    # ── Initial Sync (non-blocking) ───────────────────────────
    if vehicle.deveui:
        try:
            # 1. Sync Motor Status (just re-sync current stored state, no pending confirmation needed)
            if vehicle.moteur_coupe:
                await send_stop_command(vehicle.deveui)
                logger.info(f"Sync: STOP command sent to {vehicle.deveui}")
            else:
                await send_command(vehicle.deveui, "START")
                logger.info(f"Sync: START command sent to {vehicle.deveui}")
                
            # 2. Sync Mode Status
            if vehicle.mode_auto:
                await send_command(vehicle.deveui, "AUTO")
            else:
                await send_command(vehicle.deveui, "MANUAL")

        except Exception as e:
            logger.error(f"Failed initial sync for {vehicle.deveui}: {e}")

    return vehicle

# ── LEGACY CREATE (conservé pour compatibilité ADMIN) ─────────────────────────

@router.post("/", response_model=schemas.Vehicle)
async def create_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    vehicle_in: schemas.VehicleCreate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """Create vehicle directly (ADMIN only, legacy route)."""
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Utilisez /pair pour associer un véhicule")
    try:
        vehicle = Vehicle(
            **vehicle_in.model_dump(),
            id_utilisateur_proprietaire=current_user.id_utilisateur
        )
        db.add(vehicle)
        await db.commit()
        await db.refresh(vehicle)
        return vehicle
    except Exception as e:
        await db.rollback()
        if "duplicate key value violates unique constraint" in str(e):
            if "vehicule_deveui_key" in str(e):
                raise HTTPException(status_code=400, detail="DevEUI déjà utilisé")
            elif "vehicule_immatriculation_key" in str(e):
                raise HTTPException(status_code=400, detail="Immatriculation déjà utilisée")
        raise HTTPException(status_code=500, detail="Erreur lors de la création du véhicule")

# ── UPDATE ────────────────────────────────────────────────────────────────────

@router.put("/{id}", response_model=schemas.Vehicle)
async def update_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    vehicle_in: schemas.VehicleUpdate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """Update a vehicle. Owner or ADMIN only."""
    result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == id))
    vehicle = result.scalars().first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Véhicule introuvable")
        
    # Apply timeouts (auto-reset if > 30s)
    await _apply_command_timeouts([vehicle], db)

    if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
        raise HTTPException(status_code=403, detail="Permissions insuffisantes")

    moteur_requested = vehicle_in.moteur_coupe
    # Allow command if motor state is truly different OR if already pending (re-send)
    moteur_changed = (
        moteur_requested is not None
        and (moteur_requested != vehicle.moteur_coupe or vehicle.moteur_en_attente)
    )
    logger.info(f"[update_vehicle] id={id} moteur_requested={moteur_requested} moteur_coupe={vehicle.moteur_coupe} en_attente={vehicle.moteur_en_attente} moteur_changed={moteur_changed}")
    
    mode_auto_changed = (
        vehicle_in.mode_auto is not None
        and vehicle_in.mode_auto != vehicle.mode_auto
    )

    update_data = vehicle_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field == "annee" and value == 0:
            value = None
        # DEFERRED: Do not update moteur_coupe immediately, set en_attente instead
        if field == "moteur_coupe" and moteur_changed:
            vehicle.moteur_en_attente = True
            vehicle.moteur_commande_timestamp = datetime.utcnow()
            # We don't setattr(vehicle, "moteur_coupe", value) here
            continue
            
        setattr(vehicle, field, value)

    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)

    if moteur_changed and vehicle.deveui:
        try:
            if moteur_requested:
                logger.info(f"Sending STOP command to {vehicle.deveui} (PENDING)")
                await send_stop_command(vehicle.deveui)
            else:
                logger.info(f"Sending START command to {vehicle.deveui} (PENDING)")
                await send_command(vehicle.deveui, "START")
        except Exception as e:
            logger.error(f"Failed to trigger vehicle control downlink: {e}")
            # Reset pending if downlink failed? 
            vehicle.moteur_en_attente = False
            await db.commit()

    if mode_auto_changed and vehicle.deveui:
        try:
            if vehicle.mode_auto:
                logger.info(f"Sending AUTO command to {vehicle.deveui}")
                await send_command(vehicle.deveui, "AUTO")
            else:
                logger.info(f"Sending MANUAL command to {vehicle.deveui}")
                await send_command(vehicle.deveui, "MANUAL")
        except Exception as e:
            logger.error(f"Failed to trigger vehicle mode downlink: {e}")

    return vehicle

# ── RELEASE (Admin — Libérer un boîtier pour transfert) ──────────────────────

@router.post("/{id}/release", response_model=schemas.Vehicle)
async def release_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    [ADMIN ONLY] Libère un boîtier de son véhicule courant sans le supprimer de ChirpStack.
    Le boîtier repasse en statut DISPONIBLE, prêt à être re-appairé sur un autre véhicule.
    Un downlink STOP est envoyé pour mettre le boîtier en veille.
    """
    if current_user.role != "ADMIN":
        raise HTTPException(status_code=403, detail="Réservé aux administrateurs")

    result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == id))
    vehicle = result.scalars().first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Véhicule introuvable")
    if vehicle.statut == VehicleStatus.DISPONIBLE.value:
        raise HTTPException(status_code=409, detail="Ce boîtier est déjà en statut DISPONIBLE")

    old_deveui = vehicle.deveui
    old_owner = vehicle.id_utilisateur_proprietaire

    # ── Reset to DISPONIBLE — clear all personal/vehicle data ────────────────
    vehicle.nom = None
    vehicle.immatriculation = None
    vehicle.marque = None
    vehicle.modele = None
    vehicle.annee = None
    vehicle.id_utilisateur_proprietaire = None
    vehicle.statut = VehicleStatus.DISPONIBLE.value
    vehicle.moteur_coupe = False
    vehicle.activated_at = None
    vehicle.derniere_communication = None
    vehicle.derniere_position_lat = None
    vehicle.derniere_position_lon = None

    db.add(vehicle)
    await db.commit()
    await db.refresh(vehicle)

    logger.info(
        f"Libération boîtier : DevEUI={old_deveui} retiré du compte {old_owner} → DISPONIBLE"
    )

    # ── Send STOP downlink so device goes silent ──────────────────────────────
    if old_deveui:
        try:
            await send_stop_command(old_deveui)
            logger.info(f"STOP sent to {old_deveui} after release")
        except Exception as e:
            logger.warning(f"Could not send STOP to {old_deveui}: {e}")

    return vehicle

# ── DELETE ────────────────────────────────────────────────────────────────────

@router.delete("/{id}", response_model=schemas.Vehicle)
async def delete_vehicle(
    *,
    db: AsyncSession = Depends(deps.get_db),
    id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """Delete a vehicle. Owner or ADMIN only."""
    result = await db.execute(select(Vehicle).where(Vehicle.id_vehicule == id))
    vehicle = result.scalars().first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Véhicule introuvable")
    if current_user.role != "ADMIN" and vehicle.id_utilisateur_proprietaire != current_user.id_utilisateur:
        raise HTTPException(status_code=403, detail="Permissions insuffisantes")

    # ── Remove from ChirpStack (non-blocking) ──────────────────────────────
    if vehicle.deveui:
        try:
            ok = await delete_device_from_chirpstack(vehicle.deveui)
            if ok:
                logger.info(f"Device {vehicle.deveui} supprimé de ChirpStack")
            else:
                logger.warning(f"Device {vehicle.deveui} NON supprimé de ChirpStack (voir logs)")
        except Exception as cs_err:
            logger.warning(f"Erreur suppression ChirpStack pour {vehicle.deveui}: {cs_err}")

    await db.delete(vehicle)
    await db.commit()
    return vehicle
