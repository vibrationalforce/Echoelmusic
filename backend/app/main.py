"""
Echoelmusic Backend API
Production-ready FastAPI backend for biometric music streaming platform

Features:
- Session recording and management
- Real-time WebSocket collaboration
- Multi-platform streaming
- Stripe subscriptions
- NFT minting for peak moments
- Cloud GPU rendering
- Auto-distribution to music platforms
"""

from fastapi import FastAPI, WebSocket, HTTPException, BackgroundTasks, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import asyncio
import logging
from typing import Dict, List, Optional
from datetime import datetime
import json

from .config import settings
from .database import engine, get_db
from .redis_client import redis_client, pubsub
from . import models, schemas
from .routers import sessions, streaming, subscriptions, nft, rendering, distribution, collaboration

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Lifespan context manager for startup/shutdown events
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan"""
    # Startup
    logger.info("🚀 Starting Echoelmusic API...")

    # Initialize database
    async with engine.begin() as conn:
        await conn.run_sync(models.Base.metadata.create_all)
    logger.info("✅ Database initialized")

    # Connect to Redis
    await redis_client.initialize()
    logger.info("✅ Redis connected")

    # Initialize services
    logger.info("✅ Services initialized")

    yield

    # Shutdown
    logger.info("⏹️ Shutting down Echoelmusic API...")
    await redis_client.close()
    await engine.dispose()
    logger.info("✅ Cleanup complete")

# Create FastAPI app
app = FastAPI(
    title="Echoelmusic API",
    version="3.0.0",
    description="Biometric music streaming and NFT platform",
    lifespan=lifespan
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(sessions.router, prefix="/api/v1/sessions", tags=["Sessions"])
app.include_router(streaming.router, prefix="/api/v1/streaming", tags=["Streaming"])
app.include_router(subscriptions.router, prefix="/api/v1/subscriptions", tags=["Subscriptions"])
app.include_router(nft.router, prefix="/api/v1/nft", tags=["NFT"])
app.include_router(rendering.router, prefix="/api/v1/rendering", tags=["Rendering"])
app.include_router(distribution.router, prefix="/api/v1/distribution", tags=["Distribution"])
app.include_router(collaboration.router, prefix="/api/v1/collaboration", tags=["Collaboration"])

# Root endpoint
@app.get("/")
async def root():
    """API health check"""
    return {
        "name": "Echoelmusic API",
        "version": "3.0.0",
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }

# Health check endpoint
@app.get("/health")
async def health_check():
    """Detailed health check"""
    try:
        # Check Redis
        await redis_client.ping()
        redis_status = "healthy"
    except Exception as e:
        redis_status = f"unhealthy: {str(e)}"

    try:
        # Check Database
        async with engine.connect() as conn:
            await conn.execute("SELECT 1")
        db_status = "healthy"
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    return {
        "status": "healthy",
        "components": {
            "api": "healthy",
            "database": db_status,
            "redis": redis_status
        },
        "timestamp": datetime.utcnow().isoformat()
    }

# Metrics endpoint (for Prometheus)
@app.get("/metrics")
async def metrics():
    """Prometheus metrics"""
    # TODO: Implement Prometheus metrics
    return {"message": "Metrics endpoint - implement Prometheus integration"}

# WebSocket for real-time updates
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """General WebSocket endpoint for real-time updates"""
    await websocket.accept()

    try:
        while True:
            data = await websocket.receive_json()
            logger.info(f"Received WebSocket data: {data}")

            # Echo back for now
            await websocket.send_json({
                "type": "ack",
                "timestamp": datetime.utcnow().isoformat()
            })

    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        await websocket.close()

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Handle HTTP exceptions"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "timestamp": datetime.utcnow().isoformat()
        }
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
