"""
Task Queue Management with Redis/Celery
========================================

Provides async task queue for video generation with:
- Redis-backed message broker
- Celery worker pool
- Priority queue support
- Task status tracking
- Dead letter queue for failed tasks
"""

import os
import json
import asyncio
from typing import Optional, Dict, Any, List, Callable, Awaitable
from dataclasses import dataclass, field, asdict
from enum import Enum
from datetime import datetime, timedelta
import uuid
import logging
import redis.asyncio as aioredis
from celery import Celery
from celery.result import AsyncResult

logger = logging.getLogger(__name__)


class TaskStatus(Enum):
    PENDING = "pending"
    QUEUED = "queued"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class TaskPriority(Enum):
    LOW = 0
    NORMAL = 5
    HIGH = 10
    URGENT = 15


@dataclass
class VideoTask:
    """Video generation task specification"""
    task_id: str
    prompt: str
    negative_prompt: str = ""
    width: int = 1280
    height: int = 720
    num_frames: int = 49
    fps: int = 24
    seed: int = -1
    guidance_scale: float = 7.5
    num_inference_steps: int = 50
    genre: str = "cinematic"
    enable_refine: bool = True
    target_resolution: tuple = (1920, 1080)
    priority: TaskPriority = TaskPriority.NORMAL
    callback_url: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    created_at: str = field(default_factory=lambda: datetime.utcnow().isoformat())

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data['priority'] = self.priority.value
        return data

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "VideoTask":
        if isinstance(data.get('priority'), int):
            data['priority'] = TaskPriority(data['priority'])
        if isinstance(data.get('target_resolution'), list):
            data['target_resolution'] = tuple(data['target_resolution'])
        return cls(**data)


@dataclass
class TaskResult:
    """Result of a video generation task"""
    task_id: str
    status: TaskStatus
    output_path: Optional[str] = None
    thumbnail_path: Optional[str] = None
    duration_seconds: float = 0.0
    generation_time_seconds: float = 0.0
    error_message: Optional[str] = None
    progress: float = 0.0
    current_stage: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)
    completed_at: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        data = asdict(self)
        data['status'] = self.status.value
        return data


class TaskQueue:
    """
    Redis-backed task queue with Celery integration.

    Supports:
    - Priority queues
    - Task status tracking
    - Progress updates via Redis pub/sub
    - Dead letter queue for failed tasks
    - Task cancellation
    """

    def __init__(
        self,
        redis_url: str = "redis://localhost:6379/0",
        celery_broker: Optional[str] = None,
        max_retries: int = 3,
        task_timeout: int = 3600,  # 1 hour
    ):
        self.redis_url = redis_url
        self.celery_broker = celery_broker or redis_url
        self.max_retries = max_retries
        self.task_timeout = task_timeout

        # Redis connection
        self._redis: Optional[aioredis.Redis] = None

        # Celery app
        self.celery = Celery(
            "videogen",
            broker=self.celery_broker,
            backend=redis_url,
        )
        self._configure_celery()

        # Key prefixes
        self.TASK_KEY = "videogen:task:"
        self.RESULT_KEY = "videogen:result:"
        self.QUEUE_KEY = "videogen:queue"
        self.PROGRESS_CHANNEL = "videogen:progress:"
        self.DLQ_KEY = "videogen:dlq"

    def _configure_celery(self):
        """Configure Celery settings"""
        self.celery.conf.update(
            task_serializer="json",
            accept_content=["json"],
            result_serializer="json",
            timezone="UTC",
            enable_utc=True,
            task_track_started=True,
            task_time_limit=self.task_timeout,
            task_soft_time_limit=self.task_timeout - 60,
            worker_prefetch_multiplier=1,
            task_acks_late=True,
            task_reject_on_worker_lost=True,
            task_default_queue="video_generation",
            task_queues={
                "video_generation": {
                    "exchange": "video_generation",
                    "routing_key": "video.generate",
                },
                "video_refinement": {
                    "exchange": "video_refinement",
                    "routing_key": "video.refine",
                },
                "video_priority": {
                    "exchange": "video_priority",
                    "routing_key": "video.priority",
                },
            },
        )

    async def connect(self):
        """Connect to Redis"""
        if self._redis is None:
            self._redis = await aioredis.from_url(
                self.redis_url,
                encoding="utf-8",
                decode_responses=True,
            )
        return self._redis

    async def disconnect(self):
        """Disconnect from Redis"""
        if self._redis:
            await self._redis.close()
            self._redis = None

    async def enqueue(self, task: VideoTask) -> str:
        """
        Add task to queue.

        Returns:
            Task ID
        """
        redis = await self.connect()

        # Store task data
        task_key = f"{self.TASK_KEY}{task.task_id}"
        await redis.hset(task_key, mapping={"data": json.dumps(task.to_dict())})
        await redis.expire(task_key, 86400 * 7)  # 7 days TTL

        # Initialize result
        result = TaskResult(
            task_id=task.task_id,
            status=TaskStatus.QUEUED,
            current_stage="Queued for processing",
        )
        result_key = f"{self.RESULT_KEY}{task.task_id}"
        await redis.hset(result_key, mapping={"data": json.dumps(result.to_dict())})
        await redis.expire(result_key, 86400 * 7)

        # Add to priority queue
        await redis.zadd(
            self.QUEUE_KEY,
            {task.task_id: task.priority.value},
        )

        # Dispatch to Celery
        queue = "video_priority" if task.priority.value >= TaskPriority.HIGH.value else "video_generation"

        from .tasks import generate_video_task
        generate_video_task.apply_async(
            args=[task.to_dict()],
            task_id=task.task_id,
            queue=queue,
            priority=task.priority.value,
        )

        logger.info(f"Task {task.task_id} enqueued with priority {task.priority.name}")
        return task.task_id

    async def get_task(self, task_id: str) -> Optional[VideoTask]:
        """Get task by ID"""
        redis = await self.connect()
        task_key = f"{self.TASK_KEY}{task_id}"
        data = await redis.hget(task_key, "data")
        if data:
            return VideoTask.from_dict(json.loads(data))
        return None

    async def get_result(self, task_id: str) -> Optional[TaskResult]:
        """Get task result"""
        redis = await self.connect()
        result_key = f"{self.RESULT_KEY}{task_id}"
        data = await redis.hget(result_key, "data")
        if data:
            data_dict = json.loads(data)
            data_dict['status'] = TaskStatus(data_dict['status'])
            return TaskResult(**data_dict)
        return None

    async def update_progress(
        self,
        task_id: str,
        progress: float,
        stage: str,
        metadata: Optional[Dict[str, Any]] = None,
    ):
        """Update task progress and publish to subscribers"""
        redis = await self.connect()

        # Update result
        result = await self.get_result(task_id)
        if result:
            result.progress = progress
            result.current_stage = stage
            if metadata:
                result.metadata.update(metadata)

            result_key = f"{self.RESULT_KEY}{task_id}"
            await redis.hset(result_key, mapping={"data": json.dumps(result.to_dict())})

        # Publish progress update
        channel = f"{self.PROGRESS_CHANNEL}{task_id}"
        await redis.publish(
            channel,
            json.dumps({
                "task_id": task_id,
                "progress": progress,
                "stage": stage,
                "metadata": metadata or {},
            }),
        )

    async def complete_task(
        self,
        task_id: str,
        output_path: str,
        thumbnail_path: Optional[str] = None,
        duration_seconds: float = 0.0,
        generation_time_seconds: float = 0.0,
        metadata: Optional[Dict[str, Any]] = None,
    ):
        """Mark task as completed"""
        redis = await self.connect()

        result = TaskResult(
            task_id=task_id,
            status=TaskStatus.COMPLETED,
            output_path=output_path,
            thumbnail_path=thumbnail_path,
            duration_seconds=duration_seconds,
            generation_time_seconds=generation_time_seconds,
            progress=100.0,
            current_stage="Completed",
            metadata=metadata or {},
            completed_at=datetime.utcnow().isoformat(),
        )

        result_key = f"{self.RESULT_KEY}{task_id}"
        await redis.hset(result_key, mapping={"data": json.dumps(result.to_dict())})

        # Remove from queue
        await redis.zrem(self.QUEUE_KEY, task_id)

        # Publish completion
        channel = f"{self.PROGRESS_CHANNEL}{task_id}"
        await redis.publish(channel, json.dumps({"completed": True, **result.to_dict()}))

        logger.info(f"Task {task_id} completed: {output_path}")

    async def fail_task(
        self,
        task_id: str,
        error_message: str,
        retry: bool = True,
    ):
        """Mark task as failed"""
        redis = await self.connect()

        task = await self.get_task(task_id)
        retry_count = task.metadata.get("retry_count", 0) if task else 0

        if retry and retry_count < self.max_retries:
            # Retry task
            if task:
                task.metadata["retry_count"] = retry_count + 1
                task_key = f"{self.TASK_KEY}{task_id}"
                await redis.hset(task_key, mapping={"data": json.dumps(task.to_dict())})

                # Re-enqueue with delay
                await asyncio.sleep(2 ** retry_count)  # Exponential backoff
                await self.enqueue(task)
                logger.warning(f"Task {task_id} retry {retry_count + 1}/{self.max_retries}")
                return

        # Mark as failed
        result = TaskResult(
            task_id=task_id,
            status=TaskStatus.FAILED,
            error_message=error_message,
            progress=0.0,
            current_stage="Failed",
            completed_at=datetime.utcnow().isoformat(),
        )

        result_key = f"{self.RESULT_KEY}{task_id}"
        await redis.hset(result_key, mapping={"data": json.dumps(result.to_dict())})

        # Add to dead letter queue
        await redis.lpush(self.DLQ_KEY, json.dumps({
            "task_id": task_id,
            "error": error_message,
            "timestamp": datetime.utcnow().isoformat(),
        }))

        # Remove from queue
        await redis.zrem(self.QUEUE_KEY, task_id)

        # Publish failure
        channel = f"{self.PROGRESS_CHANNEL}{task_id}"
        await redis.publish(channel, json.dumps({"failed": True, "error": error_message}))

        logger.error(f"Task {task_id} failed: {error_message}")

    async def cancel_task(self, task_id: str) -> bool:
        """Cancel a pending or processing task"""
        redis = await self.connect()

        result = await self.get_result(task_id)
        if not result:
            return False

        if result.status in [TaskStatus.COMPLETED, TaskStatus.FAILED, TaskStatus.CANCELLED]:
            return False

        # Revoke Celery task
        self.celery.control.revoke(task_id, terminate=True)

        # Update status
        result.status = TaskStatus.CANCELLED
        result.current_stage = "Cancelled by user"
        result.completed_at = datetime.utcnow().isoformat()

        result_key = f"{self.RESULT_KEY}{task_id}"
        await redis.hset(result_key, mapping={"data": json.dumps(result.to_dict())})

        # Remove from queue
        await redis.zrem(self.QUEUE_KEY, task_id)

        logger.info(f"Task {task_id} cancelled")
        return True

    async def get_queue_stats(self) -> Dict[str, Any]:
        """Get queue statistics"""
        redis = await self.connect()

        queue_length = await redis.zcard(self.QUEUE_KEY)
        dlq_length = await redis.llen(self.DLQ_KEY)

        # Count by status
        status_counts = {s.value: 0 for s in TaskStatus}

        # Get all result keys (limited scan)
        cursor = 0
        while True:
            cursor, keys = await redis.scan(cursor, match=f"{self.RESULT_KEY}*", count=100)
            for key in keys:
                data = await redis.hget(key, "data")
                if data:
                    result = json.loads(data)
                    status_counts[result.get("status", "unknown")] += 1
            if cursor == 0:
                break

        return {
            "queue_length": queue_length,
            "dead_letter_queue": dlq_length,
            "status_counts": status_counts,
            "timestamp": datetime.utcnow().isoformat(),
        }

    async def subscribe_progress(
        self,
        task_id: str,
        callback: Callable[[Dict[str, Any]], Awaitable[None]],
    ):
        """Subscribe to task progress updates"""
        redis = await aioredis.from_url(self.redis_url)
        pubsub = redis.pubsub()

        channel = f"{self.PROGRESS_CHANNEL}{task_id}"
        await pubsub.subscribe(channel)

        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    await callback(data)

                    # Stop on completion or failure
                    if data.get("completed") or data.get("failed"):
                        break
        finally:
            await pubsub.unsubscribe(channel)
            await redis.close()

    async def cleanup_old_tasks(self, max_age_days: int = 7):
        """Clean up old completed/failed tasks"""
        redis = await self.connect()
        cutoff = datetime.utcnow() - timedelta(days=max_age_days)

        cursor = 0
        deleted = 0

        while True:
            cursor, keys = await redis.scan(cursor, match=f"{self.RESULT_KEY}*", count=100)
            for key in keys:
                data = await redis.hget(key, "data")
                if data:
                    result = json.loads(data)
                    if result.get("completed_at"):
                        completed = datetime.fromisoformat(result["completed_at"])
                        if completed < cutoff:
                            task_id = key.replace(self.RESULT_KEY, "")
                            await redis.delete(key)
                            await redis.delete(f"{self.TASK_KEY}{task_id}")
                            deleted += 1
            if cursor == 0:
                break

        logger.info(f"Cleaned up {deleted} old tasks")
        return deleted
