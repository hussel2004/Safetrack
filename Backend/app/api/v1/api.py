from fastapi import APIRouter
from app.api.v1.endpoints import auth

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
from app.api.v1.endpoints import vehicles
api_router.include_router(vehicles.router, prefix="/vehicles", tags=["vehicles"])
from app.api.v1.endpoints import geofences
api_router.include_router(geofences.router, prefix="/geofences", tags=["geofences"])
from app.api.v1.endpoints import tracking
api_router.include_router(tracking.router, prefix="/tracking", tags=["tracking"])
from app.api.v1.endpoints import alerts
api_router.include_router(alerts.router, prefix="/alerts", tags=["alerts"])
from app.api.v1.endpoints import users
api_router.include_router(users.router, prefix="/users", tags=["users"])
