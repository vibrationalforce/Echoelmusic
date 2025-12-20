"""
FastAPI REST API for Video Generation
=====================================

Endpoints:
- POST /generate - Start video generation
- GET /status/{task_id} - Check task status
- GET /result/{task_id} - Get generation result
- WS /ws/{task_id} - WebSocket for real-time progress
- GET /health - Health check
- GET /models - List available models
"""

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from enum import Enum
import asyncio
import uuid
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Echoelmusic Video Generation API",
    description="State-of-the-art Text-to-Video Generation (2025)",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================================
# Pydantic Models
# ============================================================================

class VideoResolution(str, Enum):
    SD_480P = "480p"
    HD_720P = "720p"
    FHD_1080P = "1080p"
    QHD_1440P = "1440p"
    UHD_4K = "4k"
    UHD_8K = "8k"


class VideoGenre(str, Enum):
    CINEMATIC = "cinematic"
    ANIME = "anime"
    REALISTIC = "realistic"
    ARTISTIC = "artistic"
    DOCUMENTARY = "documentary"
    MUSIC_VIDEO = "music_video"
    COMMERCIAL = "commercial"
    SOCIAL_MEDIA = "social_media"
    ABSTRACT = "abstract"
    NATURE = "nature"
    SCIFI = "scifi"
    FANTASY = "fantasy"


class GenerationRequest(BaseModel):
    """Request model for video generation"""
    prompt: str = Field(..., min_length=1, max_length=2000, description="Text prompt for video generation")
    negative_prompt: Optional[str] = Field(default="blurry, low quality, distorted", description="Negative prompt")

    # Video settings
    duration_seconds: float = Field(default=4.0, ge=1.0, le=60.0, description="Video duration in seconds")
    fps: int = Field(default=24, ge=12, le=60, description="Frames per second")
    resolution: VideoResolution = Field(default=VideoResolution.HD_720P)
    aspect_ratio: Optional[str] = Field(default="16:9", description="Aspect ratio (16:9, 9:16, 1:1, 4:3)")

    # Style settings
    genre: VideoGenre = Field(default=VideoGenre.CINEMATIC)
    style_strength: float = Field(default=0.7, ge=0.0, le=1.0, description="Style influence strength")

    # Generation settings
    seed: Optional[int] = Field(default=None, description="Random seed for reproducibility")
    guidance_scale: float = Field(default=7.5, ge=1.0, le=20.0)
    num_inference_steps: int = Field(default=50, ge=10, le=150)

    # Advanced settings
    use_prompt_expansion: bool = Field(default=True, description="Expand prompt with LLM")
    enable_8k_upscale: bool = Field(default=False, description="Enable 8K upscaling")
    motion_bucket_id: Optional[int] = Field(default=None, ge=0, le=255, description="Camera motion speed (0=static, 255=fast)")
    enable_face_consistency: bool = Field(default=False, description="Enable IP-Adapter FaceID")
    face_reference_url: Optional[str] = Field(default=None, description="Reference face image URL")

    # Callback
    webhook_url: Optional[str] = Field(default=None, description="Webhook URL for completion notification")


class TaskStatus(str, Enum):
    PENDING = "pending"
    PROCESSING = "processing"
    EXPANDING_PROMPT = "expanding_prompt"
    GENERATING_BASE = "generating_base"
    REFINING = "refining"
    UPSCALING = "upscaling"
    ENCODING = "encoding"
    COMPLETED = "completed"
    FAILED = "failed"


class GenerationResponse(BaseModel):
    """Response model for generation request"""
    task_id: str
    status: TaskStatus
    message: str
    estimated_time_seconds: Optional[float] = None
    queue_position: Optional[int] = None


class TaskStatusResponse(BaseModel):
    """Response model for task status"""
    task_id: str
    status: TaskStatus
    progress: float = Field(ge=0.0, le=1.0)
    current_step: str
    elapsed_seconds: float
    eta_seconds: Optional[float] = None
    preview_url: Optional[str] = None
    error: Optional[str] = None


class TaskResultResponse(BaseModel):
    """Response model for completed task"""
    task_id: str
    status: TaskStatus
    video_url: str
    thumbnail_url: Optional[str] = None
    duration_seconds: float
    resolution: str
    file_size_mb: float
    generation_time_seconds: float
    metadata: Dict[str, Any] = {}


class ModelInfo(BaseModel):
    """Model information"""
    name: str
    version: str
    description: str
    max_resolution: str
    max_duration_seconds: float
    supported_genres: List[str]
    vram_required_gb: float


# ============================================================================
# In-Memory Task Store (Replace with Redis in production)
# ============================================================================

class TaskStore:
    """Simple in-memory task store (use Redis in production)"""

    def __init__(self):
        self._tasks: Dict[str, Dict[str, Any]] = {}

    def create_task(self, request: GenerationRequest) -> str:
        task_id = str(uuid.uuid4())
        self._tasks[task_id] = {
            "id": task_id,
            "status": TaskStatus.PENDING,
            "progress": 0.0,
            "current_step": "Queued",
            "request": request.dict(),
            "created_at": datetime.utcnow().isoformat(),
            "started_at": None,
            "completed_at": None,
            "result": None,
            "error": None
        }
        return task_id

    def get_task(self, task_id: str) -> Optional[Dict]:
        return self._tasks.get(task_id)

    def update_task(self, task_id: str, **kwargs) -> None:
        if task_id in self._tasks:
            self._tasks[task_id].update(kwargs)

    def list_tasks(self, limit: int = 100) -> List[Dict]:
        tasks = list(self._tasks.values())
        return sorted(tasks, key=lambda x: x["created_at"], reverse=True)[:limit]


task_store = TaskStore()


# ============================================================================
# WebSocket Connection Manager
# ============================================================================

class ConnectionManager:
    """Manages WebSocket connections for progress streaming"""

    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, task_id: str):
        await websocket.accept()
        if task_id not in self.active_connections:
            self.active_connections[task_id] = []
        self.active_connections[task_id].append(websocket)
        logger.info(f"WebSocket connected for task {task_id}")

    def disconnect(self, websocket: WebSocket, task_id: str):
        if task_id in self.active_connections:
            self.active_connections[task_id].remove(websocket)
            if not self.active_connections[task_id]:
                del self.active_connections[task_id]
        logger.info(f"WebSocket disconnected for task {task_id}")

    async def broadcast(self, task_id: str, message: Dict):
        if task_id in self.active_connections:
            for connection in self.active_connections[task_id]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.warning(f"Failed to send WebSocket message: {e}")


ws_manager = ConnectionManager()


# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/models", response_model=List[ModelInfo])
async def list_models():
    """List available video generation models"""
    return [
        ModelInfo(
            name="wan2.2-t2v-14b",
            version="2.2",
            description="Wan 14B Text-to-Video with MoE architecture",
            max_resolution="4K",
            max_duration_seconds=30.0,
            supported_genres=[g.value for g in VideoGenre],
            vram_required_gb=24.0
        ),
        ModelInfo(
            name="wan2.2-t2v-1.3b",
            version="2.2",
            description="Wan 1.3B Text-to-Video (faster, less VRAM)",
            max_resolution="1080p",
            max_duration_seconds=10.0,
            supported_genres=[g.value for g in VideoGenre],
            vram_required_gb=8.0
        )
    ]


@app.post("/generate", response_model=GenerationResponse)
async def generate_video(request: GenerationRequest, background_tasks: BackgroundTasks):
    """
    Start video generation task.

    Returns task ID for tracking progress.
    """
    # Create task
    task_id = task_store.create_task(request)

    # Estimate time based on settings
    base_time = 60  # seconds
    duration_factor = request.duration_seconds / 4.0
    resolution_factor = {
        VideoResolution.SD_480P: 0.5,
        VideoResolution.HD_720P: 1.0,
        VideoResolution.FHD_1080P: 2.0,
        VideoResolution.QHD_1440P: 4.0,
        VideoResolution.UHD_4K: 8.0,
        VideoResolution.UHD_8K: 16.0
    }.get(request.resolution, 1.0)

    estimated_time = base_time * duration_factor * resolution_factor

    if request.enable_8k_upscale:
        estimated_time *= 2

    # Queue task for processing
    background_tasks.add_task(process_generation_task, task_id)

    return GenerationResponse(
        task_id=task_id,
        status=TaskStatus.PENDING,
        message="Task queued for processing",
        estimated_time_seconds=estimated_time,
        queue_position=1
    )


@app.get("/status/{task_id}", response_model=TaskStatusResponse)
async def get_task_status(task_id: str):
    """Get status of a generation task"""
    task = task_store.get_task(task_id)

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    created_at = datetime.fromisoformat(task["created_at"])
    elapsed = (datetime.utcnow() - created_at).total_seconds()

    return TaskStatusResponse(
        task_id=task_id,
        status=task["status"],
        progress=task["progress"],
        current_step=task["current_step"],
        elapsed_seconds=elapsed,
        eta_seconds=task.get("eta_seconds"),
        preview_url=task.get("preview_url"),
        error=task.get("error")
    )


@app.get("/result/{task_id}", response_model=TaskResultResponse)
async def get_task_result(task_id: str):
    """Get result of a completed generation task"""
    task = task_store.get_task(task_id)

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    if task["status"] != TaskStatus.COMPLETED:
        raise HTTPException(
            status_code=400,
            detail=f"Task not completed. Current status: {task['status']}"
        )

    result = task.get("result", {})

    return TaskResultResponse(
        task_id=task_id,
        status=TaskStatus.COMPLETED,
        video_url=result.get("video_url", ""),
        thumbnail_url=result.get("thumbnail_url"),
        duration_seconds=result.get("duration_seconds", 0),
        resolution=result.get("resolution", ""),
        file_size_mb=result.get("file_size_mb", 0),
        generation_time_seconds=result.get("generation_time_seconds", 0),
        metadata=result.get("metadata", {})
    )


@app.websocket("/ws/{task_id}")
async def websocket_endpoint(websocket: WebSocket, task_id: str):
    """WebSocket endpoint for real-time progress streaming"""
    await ws_manager.connect(websocket, task_id)

    try:
        while True:
            # Wait for messages (keep-alive or cancel requests)
            try:
                data = await asyncio.wait_for(websocket.receive_json(), timeout=30.0)

                if data.get("action") == "cancel":
                    task_store.update_task(task_id, status=TaskStatus.FAILED, error="Cancelled by user")
                    await websocket.send_json({"type": "cancelled"})
                    break

            except asyncio.TimeoutError:
                # Send ping to keep connection alive
                await websocket.send_json({"type": "ping"})

            # Check if task is complete
            task = task_store.get_task(task_id)
            if task and task["status"] in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
                break

    except WebSocketDisconnect:
        pass
    finally:
        ws_manager.disconnect(websocket, task_id)


@app.delete("/cancel/{task_id}")
async def cancel_task(task_id: str):
    """Cancel a pending or processing task"""
    task = task_store.get_task(task_id)

    if not task:
        raise HTTPException(status_code=404, detail="Task not found")

    if task["status"] in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
        raise HTTPException(status_code=400, detail="Task already finished")

    task_store.update_task(task_id, status=TaskStatus.FAILED, error="Cancelled")

    return {"message": "Task cancelled", "task_id": task_id}


# ============================================================================
# Background Task Processing
# ============================================================================

async def process_generation_task(task_id: str):
    """Process a video generation task"""
    import time

    task = task_store.get_task(task_id)
    if not task:
        return

    request = GenerationRequest(**task["request"])

    try:
        # Update status
        task_store.update_task(
            task_id,
            status=TaskStatus.PROCESSING,
            started_at=datetime.utcnow().isoformat()
        )

        # Step 1: Prompt expansion
        if request.use_prompt_expansion:
            task_store.update_task(
                task_id,
                status=TaskStatus.EXPANDING_PROMPT,
                current_step="Expanding prompt with LLM",
                progress=0.1
            )
            await ws_manager.broadcast(task_id, {
                "type": "progress",
                "progress": 0.1,
                "step": "Expanding prompt"
            })
            await asyncio.sleep(2)  # Simulate prompt expansion

        # Step 2: Base generation
        task_store.update_task(
            task_id,
            status=TaskStatus.GENERATING_BASE,
            current_step="Generating base video",
            progress=0.2
        )

        # Simulate generation progress
        for progress in range(20, 70, 5):
            await asyncio.sleep(1)
            task_store.update_task(task_id, progress=progress / 100)
            await ws_manager.broadcast(task_id, {
                "type": "progress",
                "progress": progress / 100,
                "step": f"Denoising step {progress - 20}/{50}"
            })

        # Step 3: Refinement
        task_store.update_task(
            task_id,
            status=TaskStatus.REFINING,
            current_step="Refining video quality",
            progress=0.7
        )
        await asyncio.sleep(3)

        # Step 4: Upscaling (if enabled)
        if request.enable_8k_upscale:
            task_store.update_task(
                task_id,
                status=TaskStatus.UPSCALING,
                current_step="Upscaling to 8K",
                progress=0.8
            )
            await asyncio.sleep(5)

        # Step 5: Encoding
        task_store.update_task(
            task_id,
            status=TaskStatus.ENCODING,
            current_step="Encoding video",
            progress=0.95
        )
        await asyncio.sleep(2)

        # Complete
        task_store.update_task(
            task_id,
            status=TaskStatus.COMPLETED,
            progress=1.0,
            current_step="Complete",
            completed_at=datetime.utcnow().isoformat(),
            result={
                "video_url": f"/videos/{task_id}.mp4",
                "thumbnail_url": f"/thumbnails/{task_id}.jpg",
                "duration_seconds": request.duration_seconds,
                "resolution": request.resolution.value,
                "file_size_mb": 25.0,
                "generation_time_seconds": 45.0,
                "metadata": {
                    "prompt": request.prompt,
                    "model": "wan2.2-t2v-14b",
                    "seed": request.seed or 42
                }
            }
        )

        await ws_manager.broadcast(task_id, {
            "type": "complete",
            "video_url": f"/videos/{task_id}.mp4"
        })

    except Exception as e:
        logger.error(f"Task {task_id} failed: {e}")
        task_store.update_task(
            task_id,
            status=TaskStatus.FAILED,
            error=str(e)
        )
        await ws_manager.broadcast(task_id, {
            "type": "error",
            "error": str(e)
        })


# ============================================================================
# API Class Wrapper
# ============================================================================

class VideoGenAPI:
    """High-level API wrapper for video generation"""

    def __init__(self, base_url: str = "http://localhost:8000"):
        self.base_url = base_url

    async def generate(self, request: GenerationRequest) -> str:
        """Submit generation request, returns task_id"""
        # In production, use httpx or aiohttp
        task_id = task_store.create_task(request)
        await process_generation_task(task_id)
        return task_id

    async def get_status(self, task_id: str) -> Dict:
        """Get task status"""
        return task_store.get_task(task_id) or {}

    async def wait_for_completion(
        self,
        task_id: str,
        timeout: float = 300.0
    ) -> Dict:
        """Wait for task to complete"""
        import time
        start = time.time()

        while time.time() - start < timeout:
            task = task_store.get_task(task_id)
            if task and task["status"] in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
                return task
            await asyncio.sleep(1)

        raise TimeoutError(f"Task {task_id} did not complete within {timeout}s")


# ============================================================================
# Additional API Endpoints
# ============================================================================

@app.get("/genres")
async def list_genres():
    """List all available video genres with descriptions"""
    genre_descriptions = {
        VideoGenre.CINEMATIC: "Hollywood-style dramatic visuals with high production value",
        VideoGenre.ANIME: "Japanese animation style with vibrant colors and expressive characters",
        VideoGenre.REALISTIC: "Photorealistic rendering with natural lighting and textures",
        VideoGenre.ARTISTIC: "Abstract and creative visuals with artistic interpretations",
        VideoGenre.DOCUMENTARY: "Educational and informative visual style",
        VideoGenre.MUSIC_VIDEO: "Dynamic visuals synchronized with music and rhythm",
        VideoGenre.COMMERCIAL: "Professional advertising-quality visuals",
        VideoGenre.SOCIAL_MEDIA: "Vertical format optimized for social platforms",
        VideoGenre.ABSTRACT: "Non-representational geometric and color explorations",
        VideoGenre.NATURE: "Natural landscapes, wildlife, and environmental imagery",
        VideoGenre.SCIFI: "Science fiction with futuristic technology and space themes",
        VideoGenre.FANTASY: "Magical worlds with mythical creatures and enchanted settings",
    }
    return {
        "genres": [
            {"id": g.value, "name": g.name.replace("_", " ").title(), "description": genre_descriptions.get(g, "")}
            for g in VideoGenre
        ]
    }


@app.get("/system")
async def system_info():
    """Get system hardware and resource information"""
    import torch
    import platform

    gpu_info = None
    if torch.cuda.is_available():
        gpu_info = {
            "name": torch.cuda.get_device_name(0),
            "memory_total_gb": torch.cuda.get_device_properties(0).total_memory / (1024**3),
            "memory_free_gb": (torch.cuda.get_device_properties(0).total_memory - torch.cuda.memory_allocated()) / (1024**3),
            "compute_capability": f"{torch.cuda.get_device_properties(0).major}.{torch.cuda.get_device_properties(0).minor}",
        }

    return {
        "platform": platform.system(),
        "python_version": platform.python_version(),
        "torch_version": torch.__version__,
        "cuda_available": torch.cuda.is_available(),
        "cuda_version": torch.version.cuda if torch.cuda.is_available() else None,
        "gpu": gpu_info,
        "api_version": "1.0.0",
    }


@app.get("/download")
async def download_video(path: str):
    """Download generated video file"""
    import os
    from pathlib import Path

    # Security: validate path
    safe_path = Path(path).resolve()
    output_dir = Path("/tmp/videogen/output").resolve()

    # Allow paths in output directory only
    if not str(safe_path).startswith(str(output_dir)):
        raise HTTPException(status_code=403, detail="Access denied")

    if not safe_path.exists():
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(
        path=str(safe_path),
        media_type="video/mp4",
        filename=safe_path.name
    )


@app.get("/thumbnail")
async def get_thumbnail(path: str):
    """Get video thumbnail"""
    import os
    from pathlib import Path

    safe_path = Path(path).resolve()
    output_dir = Path("/tmp/videogen/output").resolve()

    if not str(safe_path).startswith(str(output_dir)):
        raise HTTPException(status_code=403, detail="Access denied")

    if not safe_path.exists():
        raise HTTPException(status_code=404, detail="Thumbnail not found")

    return FileResponse(
        path=str(safe_path),
        media_type="image/jpeg",
        filename=safe_path.name
    )


@app.post("/batch")
async def batch_generate(requests: List[GenerationRequest], background_tasks: BackgroundTasks):
    """Submit multiple generation requests as a batch"""
    task_ids = []
    for request in requests:
        task_id = task_store.create_task(request)
        task_ids.append(task_id)
        background_tasks.add_task(process_generation_task, task_id)

    return {
        "batch_id": str(uuid.uuid4()),
        "task_ids": task_ids,
        "total": len(task_ids),
        "message": f"Batch of {len(task_ids)} tasks queued"
    }


# ============================================================================
# Error Handlers
# ============================================================================

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler for unhandled errors"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "detail": str(exc) if app.debug else "An unexpected error occurred",
            "type": type(exc).__name__
        }
    )


@app.exception_handler(ValueError)
async def value_error_handler(request, exc):
    """Handler for validation errors"""
    return JSONResponse(
        status_code=400,
        content={
            "error": "Validation error",
            "detail": str(exc)
        }
    )
