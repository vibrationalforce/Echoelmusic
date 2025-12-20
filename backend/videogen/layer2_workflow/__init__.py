"""
Layer 2: Workflow Logic & Orchestration
- FastAPI async REST API
- Redis/Celery task queue
- Two-stage generation pipeline (base + refine)
- WebSocket progress streaming
"""

from .api import app, VideoGenAPI
from .queue import TaskQueue, VideoTask, TaskResult, TaskStatus, TaskPriority
from .tasks import generate_video_task, refine_video_task, batch_generate_task
from .refiner import VideoRefiner, RefineConfig, RefineResult

__all__ = [
    "app",
    "VideoGenAPI",
    "TaskQueue",
    "VideoTask",
    "TaskResult",
    "TaskStatus",
    "TaskPriority",
    "generate_video_task",
    "refine_video_task",
    "batch_generate_task",
    "VideoRefiner",
    "RefineConfig",
    "RefineResult",
]
