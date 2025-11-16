"""Cloud GPU rendering endpoints"""

from fastapi import APIRouter
from .. import schemas
import uuid
from ..redis_client import redis_client
import json

router = APIRouter()


@router.post("/submit", response_model=schemas.RenderSubmitResponse)
async def submit_render_job(request: schemas.RenderSubmitRequest):
    """Submit job to GPU render queue"""

    job_id = str(uuid.uuid4())

    job_data = {
        "job_id": job_id,
        "session_id": request.session_id,
        "format": request.output_format,
        "quality": request.quality,
        "effects": request.effects,
        "status": "queued"
    }

    # Add to Redis queue
    await redis_client.lpush("gpu_render_queue", json.dumps(job_data))

    # Estimate render time based on quality
    quality_times = {"1080p": 300, "4k": 900, "8k": 2400}
    estimated_time = quality_times.get(request.quality, 600)

    return schemas.RenderSubmitResponse(
        job_id=job_id,
        estimated_time=estimated_time,
        status="queued"
    )


@router.get("/{job_id}/status", response_model=schemas.RenderStatus)
async def get_render_status(job_id: str):
    """Get render job status"""
    # TODO: Query actual job status from database/Redis
    return schemas.RenderStatus(
        job_id=job_id,
        status="processing",
        progress=45.0,
        output_url=None,
        error_message=None,
        estimated_time_remaining=275
    )
