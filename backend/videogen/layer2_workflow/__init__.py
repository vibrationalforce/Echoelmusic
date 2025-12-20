"""
Layer 2: Workflow Logic & Orchestration
- FastAPI async REST API
- Redis/Celery task queue
- Two-stage generation pipeline (base + refine)
- WebSocket progress streaming
- Prometheus metrics & structured logging
- Internationalization (i18n) support for 22+ languages
- Progressive Frame Streaming
"""

from .api import app, VideoGenAPI
from .queue import TaskQueue, VideoTask, TaskResult, TaskStatus, TaskPriority
from .tasks import generate_video_task, refine_video_task, batch_generate_task
from .refiner import VideoRefiner, RefineConfig, RefineResult
from .observability import (
    StructuredLogger,
    LogContext,
    structured_logger,
    MetricsCollector,
    metrics,
    task_context,
    log_operation,
    RequestLoggingMiddleware,
    get_health_details,
)
from .rate_limiter import (
    RateLimiter,
    RateLimitConfig,
    RateLimitMiddleware,
    rate_limit,
)
from .webhooks import (
    WebhookClient,
    WebhookManager,
    WebhookEvent,
    webhook_manager,
    verify_webhook_signature,
)
from .i18n import (
    Language,
    MessageKey,
    I18n,
    i18n,
    t,
)
from .progressive_output import (
    StreamQuality,
    StreamEventType,
    StreamConfig,
    StreamEvent,
    GenerationProgress,
    FrameEncoder,
    FrameCache,
    ProgressiveOutputStream,
    WebSocketStreamHandler,
    get_progressive_stream,
    stream_generation,
)
from .genius_routes import router as genius_router

__all__ = [
    # API
    "app",
    "VideoGenAPI",
    # Queue
    "TaskQueue",
    "VideoTask",
    "TaskResult",
    "TaskStatus",
    "TaskPriority",
    # Tasks
    "generate_video_task",
    "refine_video_task",
    "batch_generate_task",
    # Refiner
    "VideoRefiner",
    "RefineConfig",
    "RefineResult",
    # Observability
    "StructuredLogger",
    "LogContext",
    "structured_logger",
    "MetricsCollector",
    "metrics",
    "task_context",
    "log_operation",
    "RequestLoggingMiddleware",
    "get_health_details",
    # Rate Limiting
    "RateLimiter",
    "RateLimitConfig",
    "RateLimitMiddleware",
    "rate_limit",
    # Webhooks
    "WebhookClient",
    "WebhookManager",
    "WebhookEvent",
    "webhook_manager",
    "verify_webhook_signature",
    # Internationalization
    "Language",
    "MessageKey",
    "I18n",
    "i18n",
    "t",
    # Progressive Streaming
    "StreamQuality",
    "StreamEventType",
    "StreamConfig",
    "StreamEvent",
    "GenerationProgress",
    "FrameEncoder",
    "FrameCache",
    "ProgressiveOutputStream",
    "WebSocketStreamHandler",
    "get_progressive_stream",
    "stream_generation",
    # Super Genius AI Routes
    "genius_router",
]
