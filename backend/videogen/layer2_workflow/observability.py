"""
Production Observability Stack
==============================

Prometheus metrics, structured logging, and tracing for video generation API.

Features:
- Prometheus metrics (counters, histograms, gauges)
- Structured JSON logging with correlation IDs
- Request/response logging middleware
- GPU metrics collection
- Task queue depth monitoring
"""

import os
import time
import json
import uuid
import logging
import functools
from typing import Optional, Dict, Any, Callable
from datetime import datetime
from dataclasses import dataclass, field, asdict
from contextlib import asynccontextmanager
from enum import Enum

# Prometheus metrics
try:
    from prometheus_client import (
        Counter, Histogram, Gauge, Info,
        generate_latest, CONTENT_TYPE_LATEST,
        CollectorRegistry, multiprocess, REGISTRY
    )
    PROMETHEUS_AVAILABLE = True
except ImportError:
    PROMETHEUS_AVAILABLE = False


# ============================================================================
# Structured Logger
# ============================================================================

class LogLevel(str, Enum):
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


@dataclass
class LogContext:
    """Structured log context for correlation and tracing"""
    request_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    task_id: Optional[str] = None
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    extra: Dict[str, Any] = field(default_factory=dict)

    def with_task(self, task_id: str) -> "LogContext":
        """Create new context with task_id"""
        return LogContext(
            request_id=self.request_id,
            task_id=task_id,
            user_id=self.user_id,
            session_id=self.session_id,
            extra=self.extra.copy()
        )


class StructuredFormatter(logging.Formatter):
    """JSON structured log formatter for production logging"""

    def __init__(
        self,
        service_name: str = "videogen-api",
        environment: str = "production",
        include_stack_trace: bool = True
    ):
        super().__init__()
        self.service_name = service_name
        self.environment = environment
        self.include_stack_trace = include_stack_trace
        self.hostname = os.environ.get("HOSTNAME", "unknown")

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname.lower(),
            "logger": record.name,
            "message": record.getMessage(),
            "service": self.service_name,
            "environment": self.environment,
            "hostname": self.hostname,
            "source": {
                "file": record.pathname,
                "line": record.lineno,
                "function": record.funcName,
            }
        }

        # Add correlation IDs if present
        if hasattr(record, "request_id"):
            log_entry["request_id"] = record.request_id
        if hasattr(record, "task_id"):
            log_entry["task_id"] = record.task_id
        if hasattr(record, "user_id"):
            log_entry["user_id"] = record.user_id

        # Add extra fields
        if hasattr(record, "extra_fields") and record.extra_fields:
            log_entry["extra"] = record.extra_fields

        # Add exception info
        if record.exc_info and self.include_stack_trace:
            log_entry["exception"] = {
                "type": record.exc_info[0].__name__ if record.exc_info[0] else None,
                "message": str(record.exc_info[1]) if record.exc_info[1] else None,
                "traceback": self.formatException(record.exc_info)
            }

        return json.dumps(log_entry, default=str, ensure_ascii=False)


class StructuredLogger:
    """Production-ready structured logger with context support"""

    def __init__(
        self,
        name: str = "videogen",
        level: str = "INFO",
        json_output: bool = True,
        service_name: str = "videogen-api"
    ):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(getattr(logging, level.upper()))
        self.context: Optional[LogContext] = None

        # Remove existing handlers
        self.logger.handlers.clear()

        # Add handler with appropriate formatter
        handler = logging.StreamHandler()
        if json_output:
            handler.setFormatter(StructuredFormatter(service_name=service_name))
        else:
            handler.setFormatter(logging.Formatter(
                "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s"
            ))
        self.logger.addHandler(handler)

    def with_context(self, context: LogContext) -> "StructuredLogger":
        """Create logger bound to specific context"""
        new_logger = StructuredLogger.__new__(StructuredLogger)
        new_logger.logger = self.logger
        new_logger.context = context
        return new_logger

    def _log(
        self,
        level: int,
        message: str,
        extra: Optional[Dict[str, Any]] = None,
        exc_info: bool = False
    ):
        record_extra = {}

        if self.context:
            record_extra["request_id"] = self.context.request_id
            if self.context.task_id:
                record_extra["task_id"] = self.context.task_id
            if self.context.user_id:
                record_extra["user_id"] = self.context.user_id

        if extra:
            record_extra["extra_fields"] = extra

        self.logger.log(level, message, extra=record_extra, exc_info=exc_info)

    def debug(self, message: str, **kwargs):
        self._log(logging.DEBUG, message, kwargs if kwargs else None)

    def info(self, message: str, **kwargs):
        self._log(logging.INFO, message, kwargs if kwargs else None)

    def warning(self, message: str, **kwargs):
        self._log(logging.WARNING, message, kwargs if kwargs else None)

    def error(self, message: str, exc_info: bool = True, **kwargs):
        self._log(logging.ERROR, message, kwargs if kwargs else None, exc_info=exc_info)

    def critical(self, message: str, exc_info: bool = True, **kwargs):
        self._log(logging.CRITICAL, message, kwargs if kwargs else None, exc_info=exc_info)


# Global structured logger instance
structured_logger = StructuredLogger(
    json_output=os.environ.get("LOG_FORMAT", "json").lower() == "json",
    level=os.environ.get("LOG_LEVEL", "INFO")
)


# ============================================================================
# Prometheus Metrics
# ============================================================================

if PROMETHEUS_AVAILABLE:
    # Request metrics
    REQUEST_COUNT = Counter(
        "videogen_requests_total",
        "Total HTTP requests",
        ["method", "endpoint", "status_code"]
    )

    REQUEST_LATENCY = Histogram(
        "videogen_request_latency_seconds",
        "Request latency in seconds",
        ["method", "endpoint"],
        buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0)
    )

    REQUEST_IN_PROGRESS = Gauge(
        "videogen_requests_in_progress",
        "Number of requests currently being processed",
        ["method", "endpoint"]
    )

    # Task metrics
    TASK_COUNT = Counter(
        "videogen_tasks_total",
        "Total video generation tasks",
        ["status", "resolution", "genre"]
    )

    TASK_DURATION = Histogram(
        "videogen_task_duration_seconds",
        "Task duration in seconds",
        ["resolution", "genre"],
        buckets=(5, 10, 30, 60, 120, 300, 600, 1800)
    )

    TASK_QUEUE_DEPTH = Gauge(
        "videogen_task_queue_depth",
        "Number of tasks in queue",
        ["priority"]
    )

    ACTIVE_TASKS = Gauge(
        "videogen_active_tasks",
        "Number of tasks currently being processed"
    )

    # GPU metrics
    GPU_MEMORY_USED = Gauge(
        "videogen_gpu_memory_used_bytes",
        "GPU memory currently in use",
        ["device"]
    )

    GPU_MEMORY_TOTAL = Gauge(
        "videogen_gpu_memory_total_bytes",
        "Total GPU memory",
        ["device"]
    )

    GPU_UTILIZATION = Gauge(
        "videogen_gpu_utilization_percent",
        "GPU utilization percentage",
        ["device"]
    )

    # Model metrics
    MODEL_LOAD_TIME = Histogram(
        "videogen_model_load_seconds",
        "Time to load models",
        ["model_name"],
        buckets=(1, 5, 10, 30, 60, 120, 300)
    )

    INFERENCE_TIME = Histogram(
        "videogen_inference_seconds",
        "Inference time per frame batch",
        ["model_name", "precision"],
        buckets=(0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0)
    )

    # WebSocket metrics
    WEBSOCKET_CONNECTIONS = Gauge(
        "videogen_websocket_connections",
        "Active WebSocket connections"
    )

    # Error metrics
    ERROR_COUNT = Counter(
        "videogen_errors_total",
        "Total errors",
        ["error_type", "endpoint"]
    )

    # Service info
    SERVICE_INFO = Info(
        "videogen_service",
        "Service information"
    )
    SERVICE_INFO.info({
        "version": "1.0.0",
        "model": "wan2.2-t2v-14b",
        "framework": "fastapi"
    })


@dataclass
class MetricsSnapshot:
    """Point-in-time metrics snapshot for debugging"""
    timestamp: str
    requests_total: int = 0
    requests_in_flight: int = 0
    tasks_pending: int = 0
    tasks_active: int = 0
    tasks_completed: int = 0
    tasks_failed: int = 0
    gpu_memory_used_gb: float = 0.0
    gpu_memory_total_gb: float = 0.0
    gpu_utilization: float = 0.0
    websocket_connections: int = 0
    avg_latency_ms: float = 0.0


class MetricsCollector:
    """Collects and exposes Prometheus metrics"""

    def __init__(self):
        self.enabled = PROMETHEUS_AVAILABLE

    def record_request(
        self,
        method: str,
        endpoint: str,
        status_code: int,
        duration: float
    ):
        """Record HTTP request metrics"""
        if not self.enabled:
            return

        REQUEST_COUNT.labels(
            method=method,
            endpoint=endpoint,
            status_code=str(status_code)
        ).inc()

        REQUEST_LATENCY.labels(
            method=method,
            endpoint=endpoint
        ).observe(duration)

    def record_task_start(self, resolution: str, genre: str):
        """Record task start"""
        if not self.enabled:
            return
        ACTIVE_TASKS.inc()
        TASK_COUNT.labels(status="started", resolution=resolution, genre=genre).inc()

    def record_task_complete(
        self,
        resolution: str,
        genre: str,
        duration: float,
        success: bool
    ):
        """Record task completion"""
        if not self.enabled:
            return

        ACTIVE_TASKS.dec()
        status = "completed" if success else "failed"
        TASK_COUNT.labels(status=status, resolution=resolution, genre=genre).inc()
        TASK_DURATION.labels(resolution=resolution, genre=genre).observe(duration)

    def record_error(self, error_type: str, endpoint: str):
        """Record error occurrence"""
        if not self.enabled:
            return
        ERROR_COUNT.labels(error_type=error_type, endpoint=endpoint).inc()

    def update_gpu_metrics(self):
        """Update GPU metrics from PyTorch/CUDA"""
        if not self.enabled:
            return

        try:
            import torch
            if torch.cuda.is_available():
                for i in range(torch.cuda.device_count()):
                    device = f"cuda:{i}"
                    props = torch.cuda.get_device_properties(i)

                    GPU_MEMORY_TOTAL.labels(device=device).set(props.total_memory)
                    GPU_MEMORY_USED.labels(device=device).set(
                        torch.cuda.memory_allocated(i)
                    )

                    # Note: utilization requires pynvml for accurate reading
                    # This is a placeholder
                    GPU_UTILIZATION.labels(device=device).set(0)
        except Exception:
            pass

    def update_queue_depth(self, pending: int, priority: str = "normal"):
        """Update task queue depth"""
        if not self.enabled:
            return
        TASK_QUEUE_DEPTH.labels(priority=priority).set(pending)

    def update_websocket_count(self, count: int):
        """Update WebSocket connection count"""
        if not self.enabled:
            return
        WEBSOCKET_CONNECTIONS.set(count)

    def get_metrics(self) -> bytes:
        """Get Prometheus metrics in exposition format"""
        if not self.enabled:
            return b"# Prometheus not available\n"
        return generate_latest(REGISTRY)

    def get_content_type(self) -> str:
        """Get content type for metrics endpoint"""
        if not self.enabled:
            return "text/plain"
        return CONTENT_TYPE_LATEST


# Global metrics collector
metrics = MetricsCollector()


# ============================================================================
# Middleware and Decorators
# ============================================================================

def track_request_metrics(func: Callable) -> Callable:
    """Decorator to track request metrics"""
    @functools.wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.perf_counter()
        method = "UNKNOWN"
        endpoint = func.__name__

        try:
            if PROMETHEUS_AVAILABLE:
                REQUEST_IN_PROGRESS.labels(method=method, endpoint=endpoint).inc()

            result = await func(*args, **kwargs)

            duration = time.perf_counter() - start_time
            metrics.record_request(method, endpoint, 200, duration)

            return result

        except Exception as e:
            duration = time.perf_counter() - start_time
            metrics.record_request(method, endpoint, 500, duration)
            metrics.record_error(type(e).__name__, endpoint)
            raise

        finally:
            if PROMETHEUS_AVAILABLE:
                REQUEST_IN_PROGRESS.labels(method=method, endpoint=endpoint).dec()

    return wrapper


def log_operation(operation: str, log_args: bool = True):
    """Decorator for operation logging with timing"""
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        async def async_wrapper(*args, **kwargs):
            start_time = time.perf_counter()
            request_id = str(uuid.uuid4())[:8]

            structured_logger.info(
                f"Starting {operation}",
                request_id=request_id,
                operation=operation,
                args=str(kwargs)[:200] if log_args else None
            )

            try:
                result = await func(*args, **kwargs)
                duration_ms = (time.perf_counter() - start_time) * 1000

                structured_logger.info(
                    f"Completed {operation}",
                    request_id=request_id,
                    operation=operation,
                    duration_ms=round(duration_ms, 2)
                )
                return result

            except Exception as e:
                duration_ms = (time.perf_counter() - start_time) * 1000
                structured_logger.error(
                    f"Failed {operation}: {e}",
                    request_id=request_id,
                    operation=operation,
                    duration_ms=round(duration_ms, 2),
                    error_type=type(e).__name__
                )
                raise

        @functools.wraps(func)
        def sync_wrapper(*args, **kwargs):
            start_time = time.perf_counter()
            request_id = str(uuid.uuid4())[:8]

            structured_logger.info(
                f"Starting {operation}",
                request_id=request_id,
                operation=operation
            )

            try:
                result = func(*args, **kwargs)
                duration_ms = (time.perf_counter() - start_time) * 1000

                structured_logger.info(
                    f"Completed {operation}",
                    request_id=request_id,
                    operation=operation,
                    duration_ms=round(duration_ms, 2)
                )
                return result

            except Exception as e:
                duration_ms = (time.perf_counter() - start_time) * 1000
                structured_logger.error(
                    f"Failed {operation}: {e}",
                    request_id=request_id,
                    operation=operation,
                    duration_ms=round(duration_ms, 2),
                    error_type=type(e).__name__
                )
                raise

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper

    return decorator


@asynccontextmanager
async def task_context(task_id: str, resolution: str, genre: str):
    """Context manager for task lifecycle with metrics and logging"""
    start_time = time.perf_counter()
    ctx = LogContext(task_id=task_id)
    logger = structured_logger.with_context(ctx)

    logger.info(
        "Task started",
        resolution=resolution,
        genre=genre
    )
    metrics.record_task_start(resolution, genre)

    try:
        yield logger
        duration = time.perf_counter() - start_time
        logger.info(
            "Task completed successfully",
            duration_seconds=round(duration, 2)
        )
        metrics.record_task_complete(resolution, genre, duration, success=True)

    except Exception as e:
        duration = time.perf_counter() - start_time
        logger.error(
            f"Task failed: {e}",
            duration_seconds=round(duration, 2),
            error_type=type(e).__name__
        )
        metrics.record_task_complete(resolution, genre, duration, success=False)
        raise


# ============================================================================
# FastAPI Middleware
# ============================================================================

class RequestLoggingMiddleware:
    """FastAPI middleware for request logging and metrics"""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start_time = time.perf_counter()
        request_id = str(uuid.uuid4())
        method = scope.get("method", "UNKNOWN")
        path = scope.get("path", "/")

        # Extract request details
        headers = dict(scope.get("headers", []))
        client_ip = scope.get("client", ("unknown", 0))[0]

        # Override request_id if provided in header
        if b"x-request-id" in headers:
            request_id = headers[b"x-request-id"].decode()

        status_code = 500  # Default to error

        async def send_wrapper(message):
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)

        except Exception as e:
            structured_logger.error(
                f"Request failed: {e}",
                request_id=request_id,
                method=method,
                path=path,
                client_ip=client_ip,
            )
            raise

        finally:
            duration = time.perf_counter() - start_time

            # Log request
            log_level = "info" if status_code < 400 else "warning" if status_code < 500 else "error"
            getattr(structured_logger, log_level)(
                f"{method} {path} {status_code}",
                request_id=request_id,
                method=method,
                path=path,
                status_code=status_code,
                duration_ms=round(duration * 1000, 2),
                client_ip=client_ip
            )

            # Record metrics
            metrics.record_request(method, path, status_code, duration)


# ============================================================================
# Health Check Enrichment
# ============================================================================

async def get_health_details() -> Dict[str, Any]:
    """Get detailed health check information"""
    health = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "version": "1.0.0",
        "checks": {}
    }

    # Check GPU availability
    try:
        import torch
        if torch.cuda.is_available():
            health["checks"]["gpu"] = {
                "status": "healthy",
                "device_count": torch.cuda.device_count(),
                "memory_allocated_gb": round(torch.cuda.memory_allocated() / 1e9, 2)
            }
        else:
            health["checks"]["gpu"] = {"status": "unavailable"}
    except Exception as e:
        health["checks"]["gpu"] = {"status": "error", "error": str(e)}

    # Check model readiness (placeholder)
    health["checks"]["model"] = {"status": "ready"}

    # Check task queue (placeholder)
    health["checks"]["queue"] = {"status": "healthy", "depth": 0}

    # Overall status
    unhealthy = [k for k, v in health["checks"].items()
                 if v.get("status") == "error"]
    if unhealthy:
        health["status"] = "unhealthy"
        health["unhealthy_checks"] = unhealthy

    return health


# ============================================================================
# Exports
# ============================================================================

import asyncio

__all__ = [
    # Logging
    "StructuredLogger",
    "StructuredFormatter",
    "LogContext",
    "structured_logger",
    # Metrics
    "MetricsCollector",
    "MetricsSnapshot",
    "metrics",
    # Decorators
    "track_request_metrics",
    "log_operation",
    "task_context",
    # Middleware
    "RequestLoggingMiddleware",
    # Health
    "get_health_details",
    # Constants
    "PROMETHEUS_AVAILABLE",
]
