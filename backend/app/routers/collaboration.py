"""Real-time collaboration WebSocket endpoints"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import json
from datetime import datetime
from typing import Dict, Set

from ..database import get_db
from ..redis_client import redis_client
from .. import models, schemas

router = APIRouter()

# Active WebSocket connections per room
active_connections: Dict[str, Set[WebSocket]] = {}


@router.post("/rooms", response_model=schemas.RoomResponse)
async def create_room(
    request: schemas.RoomCreate,
    db: AsyncSession = Depends(get_db)
):
    """Create collaboration room"""
    import uuid

    room_id = str(uuid.uuid4())

    room = models.CollaborationRoom(
        room_id=room_id,
        name=request.name,
        description=request.description,
        max_participants=request.max_participants,
        host_user_id=1,  # TODO: Get from auth
        active=True,
        participant_count=0
    )

    db.add(room)
    await db.commit()
    await db.refresh(room)

    return room


@router.websocket("/ws/{room_id}")
async def websocket_collab(websocket: WebSocket, room_id: str):
    """
    WebSocket for real-time collaboration

    Features:
    - Biometric data fusion from all participants
    - Real-time synchronization
    - Collaborative music creation
    """
    await websocket.accept()

    # Add to active connections
    if room_id not in active_connections:
        active_connections[room_id] = set()
    active_connections[room_id].add(websocket)

    # Subscribe to Redis pub/sub
    await redis_client.subscribe(f"room:{room_id}")
    await redis_client.sadd(f"room:{room_id}:users", str(websocket.client.host))

    try:
        while True:
            data = await websocket.receive_json()

            if data["type"] == "biometrics":
                # Fuse biometric data from all participants
                fused_data = await fuse_biometrics(room_id)

                # Broadcast to all in room
                await broadcast_to_room(room_id, {
                    "type": "fused_biometrics",
                    "data": fused_data,
                    "timestamp": datetime.utcnow().isoformat()
                })

            # Publish to Redis
            await redis_client.publish(f"room:{room_id}", json.dumps(data))

    except WebSocketDisconnect:
        active_connections[room_id].remove(websocket)
        await redis_client.srem(f"room:{room_id}:users", str(websocket.client.host))


async def broadcast_to_room(room_id: str, message: dict):
    """Broadcast message to all connections in room"""
    if room_id in active_connections:
        for connection in active_connections[room_id]:
            await connection.send_json(message)


async def fuse_biometrics(room_id: str) -> dict:
    """Fuse biometric data from all participants"""
    # TODO: Implement actual biometric fusion algorithm
    return {
        "heart_rate": 70.0,
        "hrv_coherence": 60.0,
        "breathing_rate": 6.0
    }
