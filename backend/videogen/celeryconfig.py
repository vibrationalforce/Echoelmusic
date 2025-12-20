"""
Celery Configuration for Video Generation Workers
===================================================

Production-ready configuration for distributed video generation.
"""

import os

# ============================================================
# Broker Settings (Redis)
# ============================================================
broker_url = os.environ.get("CELERY_BROKER_URL", "redis://localhost:6379/0")
result_backend = os.environ.get("CELERY_RESULT_BACKEND", "redis://localhost:6379/0")

# ============================================================
# Task Settings
# ============================================================
task_serializer = "json"
accept_content = ["json"]
result_serializer = "json"
timezone = "UTC"
enable_utc = True

# Track task start time
task_track_started = True

# Long-running task timeout (1 hour for generation)
task_time_limit = 3600
task_soft_time_limit = 3500

# Worker should only take one task at a time (GPU bound)
worker_prefetch_multiplier = 1

# Acknowledge task after completion (important for GPU tasks)
task_acks_late = True

# Re-queue task if worker dies
task_reject_on_worker_lost = True

# ============================================================
# Queue Configuration
# ============================================================
task_default_queue = "video_generation"

task_queues = {
    "video_generation": {
        "exchange": "video_generation",
        "exchange_type": "direct",
        "routing_key": "video.generate",
    },
    "video_refinement": {
        "exchange": "video_refinement",
        "exchange_type": "direct",
        "routing_key": "video.refine",
    },
    "video_priority": {
        "exchange": "video_priority",
        "exchange_type": "direct",
        "routing_key": "video.priority",
    },
}

task_routes = {
    "videogen.generate": {"queue": "video_generation"},
    "videogen.refine": {"queue": "video_refinement"},
    "videogen.batch": {"queue": "video_generation"},
}

# ============================================================
# Result Settings
# ============================================================
result_expires = 86400 * 7  # 7 days

# Store task metadata
result_extended = True

# ============================================================
# Worker Settings
# ============================================================
# Single worker concurrency (GPU constraint)
worker_concurrency = 1

# Graceful shutdown timeout
worker_cancel_long_running_tasks_on_connection_loss = True

# Log level
worker_hijack_root_logger = False

# ============================================================
# Beat Schedule (Optional periodic tasks)
# ============================================================
beat_schedule = {
    "cleanup-old-tasks": {
        "task": "videogen.cleanup",
        "schedule": 86400.0,  # Daily
    },
}
