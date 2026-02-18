from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
)

# Set all CORS enabled origins
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin) for origin in settings.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

@app.get("/")
def root():
    return {"message": "Welcome to SafeTrack API"}

from app.api.v1.api import api_router
app.include_router(api_router, prefix=settings.API_V1_STR)

# WebSocket Endpoint
from fastapi import WebSocket, WebSocketDisconnect, Depends
from app.services.notification_service import manager
from app.core import security
from app.api import deps
from jose import jwt, JWTError
from pydantic import ValidationError
from app.core.config import settings

@app.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[security.ALGORITHM])
        token_data = deps.TokenPayload(**payload)
        user_id = int(token_data.sub)
    except (JWTError, ValidationError, ValueError):
        await websocket.close(code=1008)
        return

    await manager.connect(websocket, user_id)
    try:
        while True:
            # Keep connection alive, maybe receive ack or other commands
            data = await websocket.receive_text()
            # print(f"Received from {user_id}: {data}") 
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)

