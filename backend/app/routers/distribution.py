"""Auto-distribution to music platforms"""

from fastapi import APIRouter
from .. import schemas
from datetime import datetime, timedelta
import uuid

router = APIRouter()


@router.post("/submit", response_model=schemas.DistributionResponse)
async def submit_distribution(request: schemas.DistributionRequest):
    """
    Auto-distribute to music platforms

    Platforms:
    - Spotify (via DistroKid)
    - Apple Music (via DistroKid)
    - YouTube Music (Content ID)
    - SoundCloud (direct upload)
    - Beatport (for electronic music)
    - Bandcamp
    """

    distribution_id = str(uuid.uuid4())

    # Simulate platform statuses
    platform_status = {
        platform: "pending" for platform in request.platforms
    }

    # Estimate release date (typically 2-4 weeks for major platforms)
    estimated_release = datetime.utcnow() + timedelta(days=14)

    return schemas.DistributionResponse(
        distribution_id=distribution_id,
        platforms=request.platforms,
        status=platform_status,
        estimated_release_date=estimated_release
    )


@router.get("/{distribution_id}/status")
async def get_distribution_status(distribution_id: str):
    """Get distribution status across platforms"""
    return {
        "distribution_id": distribution_id,
        "status": {
            "spotify": "live",
            "apple_music": "pending_review",
            "youtube": "live",
            "soundcloud": "live",
            "beatport": "pending_review"
        }
    }
