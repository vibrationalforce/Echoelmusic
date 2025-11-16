"""Session recording and management endpoints"""

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List
import uuid
import json
from datetime import datetime

from ..database import get_db
from ..redis_client import redis_client
from .. import models, schemas

router = APIRouter()


@router.post("/start", response_model=schemas.SessionStartResponse)
async def start_session(
    request: schemas.SessionStart,
    db: AsyncSession = Depends(get_db)
):
    """
    Start a new recording session

    Creates a session in the database, initializes Redis state, and returns
    a session ID and optional stream key for RTMP streaming.
    """
    session_id = str(uuid.uuid4())

    # Create session in database
    db_session = models.Session(
        user_id=int(request.user_id),
        session_id=session_id,
        status="recording",
        biometric_data=request.biometrics.model_dump(),
        started_at=datetime.utcnow()
    )

    db.add(db_session)
    await db.commit()
    await db.refresh(db_session)

    # Initialize Redis session state
    await redis_client.hset(f"session:{session_id}", mapping={
        "user_id": request.user_id,
        "status": "recording",
        "heart_rate": str(request.biometrics.heart_rate),
        "hrv": str(request.biometrics.hrv_coherence),
        "started_at": datetime.utcnow().isoformat()
    })

    # Generate stream key
    stream_key = f"echoel_{session_id[:12]}"

    return schemas.SessionStartResponse(
        session_id=session_id,
        stream_key=stream_key,
        started_at=db_session.started_at
    )


@router.post("/{session_id}/update")
async def update_session(
    session_id: str,
    request: schemas.SessionUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Update session with new biometric data"""

    # Update Redis (real-time state)
    if request.biometrics:
        await redis_client.hset(f"session:{session_id}", mapping={
            "heart_rate": str(request.biometrics.heart_rate),
            "hrv": str(request.biometrics.hrv_coherence),
            "last_update": datetime.utcnow().isoformat()
        })

    # Update database periodically
    stmt = select(models.Session).where(models.Session.session_id == session_id)
    result = await db.execute(stmt)
    db_session = result.scalar_one_or_none()

    if not db_session:
        raise HTTPException(status_code=404, detail="Session not found")

    if request.title:
        db_session.title = request.title
    if request.description:
        db_session.description = request.description
    if request.biometrics:
        db_session.biometric_data = request.biometrics.model_dump()

    await db.commit()

    return {"status": "updated", "session_id": session_id}


@router.post("/{session_id}/end")
async def end_session(
    session_id: str,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    End a recording session

    Finalizes the session, triggers video processing, and checks for
    emotion peaks for potential NFT minting.
    """
    stmt = select(models.Session).where(models.Session.session_id == session_id)
    result = await db.execute(stmt)
    db_session = result.scalar_one_or_none()

    if not db_session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Update session
    db_session.status = "processing"
    db_session.ended_at = datetime.utcnow()

    # Calculate duration
    if db_session.started_at:
        duration = (db_session.ended_at - db_session.started_at).total_seconds()
        db_session.duration = duration

    await db.commit()

    # Update Redis
    await redis_client.hset(f"session:{session_id}", mapping={
        "status": "processing",
        "ended_at": datetime.utcnow().isoformat()
    })

    # Queue background tasks
    # background_tasks.add_task(process_session_video, session_id)
    # background_tasks.add_task(analyze_emotion_peaks, session_id)
    # background_tasks.add_task(generate_thumbnail, session_id)

    return {
        "status": "ended",
        "session_id": session_id,
        "duration": db_session.duration
    }


@router.get("/{session_id}", response_model=schemas.SessionResponse)
async def get_session(
    session_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get session details"""
    stmt = select(models.Session).where(models.Session.session_id == session_id)
    result = await db.execute(stmt)
    db_session = result.scalar_one_or_none()

    if not db_session:
        raise HTTPException(status_code=404, detail="Session not found")

    return db_session


@router.get("/user/{user_id}", response_model=List[schemas.SessionResponse])
async def get_user_sessions(
    user_id: int,
    skip: int = 0,
    limit: int = 20,
    db: AsyncSession = Depends(get_db)
):
    """Get all sessions for a user"""
    stmt = select(models.Session)\
        .where(models.Session.user_id == user_id)\
        .offset(skip)\
        .limit(limit)\
        .order_by(models.Session.created_at.desc())

    result = await db.execute(stmt)
    sessions = result.scalars().all()

    return sessions


@router.delete("/{session_id}")
async def delete_session(
    session_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Delete a session"""
    stmt = select(models.Session).where(models.Session.session_id == session_id)
    result = await db.execute(stmt)
    db_session = result.scalar_one_or_none()

    if not db_session:
        raise HTTPException(status_code=404, detail="Session not found")

    await db.delete(db_session)
    await db.commit()

    # Clean up Redis
    await redis_client.delete(f"session:{session_id}")

    return {"status": "deleted", "session_id": session_id}
