"""
Production Readiness Module
============================

Enterprise-grade production readiness checks, validation, and monitoring
for Lambda/serverless and container deployments.

Features:
- Comprehensive health checks (GPU, memory, disk, model)
- Input validation with detailed error messages
- Startup readiness probes
- Graceful degradation
- Circuit breaker pattern
- Performance benchmarking
"""

import os
import sys
import time
import json
import asyncio
import hashlib
from typing import Optional, Dict, Any, List, Tuple, Callable
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime, timedelta
from pathlib import Path
import logging

logger = logging.getLogger(__name__)


class HealthStatus(str, Enum):
    """Health check status levels"""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"
    UNKNOWN = "unknown"


class ReadinessStatus(str, Enum):
    """Startup readiness status"""
    READY = "ready"
    STARTING = "starting"
    NOT_READY = "not_ready"
    FAILED = "failed"


@dataclass
class HealthCheckResult:
    """Result of a single health check"""
    name: str
    status: HealthStatus
    message: str = ""
    latency_ms: float = 0.0
    details: Dict[str, Any] = field(default_factory=dict)
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())


@dataclass
class SystemHealth:
    """Overall system health"""
    status: HealthStatus
    checks: List[HealthCheckResult]
    uptime_seconds: float
    version: str
    environment: str
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat())

    def to_dict(self) -> Dict[str, Any]:
        return {
            "status": self.status.value,
            "checks": [
                {
                    "name": c.name,
                    "status": c.status.value,
                    "message": c.message,
                    "latency_ms": c.latency_ms,
                    "details": c.details,
                }
                for c in self.checks
            ],
            "uptime_seconds": self.uptime_seconds,
            "version": self.version,
            "environment": self.environment,
            "timestamp": self.timestamp,
        }


@dataclass
class ValidationError:
    """Input validation error"""
    field: str
    message: str
    code: str
    value: Any = None


@dataclass
class ValidationResult:
    """Result of input validation"""
    valid: bool
    errors: List[ValidationError] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "valid": self.valid,
            "errors": [
                {
                    "field": e.field,
                    "message": e.message,
                    "code": e.code,
                }
                for e in self.errors
            ],
        }


class CircuitBreaker:
    """
    Circuit breaker pattern for fault tolerance.

    States:
    - CLOSED: Normal operation
    - OPEN: Failing, reject requests
    - HALF_OPEN: Testing recovery
    """

    def __init__(
        self,
        failure_threshold: int = 5,
        recovery_timeout: float = 30.0,
        half_open_requests: int = 3
    ):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.half_open_requests = half_open_requests

        self._failures = 0
        self._successes = 0
        self._last_failure_time: Optional[float] = None
        self._state = "closed"

    @property
    def state(self) -> str:
        if self._state == "open":
            if time.time() - self._last_failure_time > self.recovery_timeout:
                self._state = "half_open"
                self._successes = 0
        return self._state

    def record_success(self) -> None:
        self._failures = 0
        if self._state == "half_open":
            self._successes += 1
            if self._successes >= self.half_open_requests:
                self._state = "closed"

    def record_failure(self) -> None:
        self._failures += 1
        self._last_failure_time = time.time()
        if self._failures >= self.failure_threshold:
            self._state = "open"

    def allow_request(self) -> bool:
        state = self.state
        if state == "closed":
            return True
        elif state == "half_open":
            return True
        else:  # open
            return False


class ProductionHealthChecker:
    """
    Comprehensive health checking system for production.

    Checks:
    - GPU availability and memory
    - System memory
    - Disk space
    - Model loading status
    - Redis connectivity
    - External services
    """

    VERSION = "1.0.0"

    def __init__(self, environment: str = "production"):
        self.environment = environment
        self._start_time = time.time()
        self._circuit_breakers: Dict[str, CircuitBreaker] = {}
        self._readiness_status = ReadinessStatus.STARTING

    @property
    def uptime(self) -> float:
        return time.time() - self._start_time

    async def check_gpu(self) -> HealthCheckResult:
        """Check GPU availability and memory"""
        start = time.time()
        try:
            import torch

            if not torch.cuda.is_available():
                return HealthCheckResult(
                    name="gpu",
                    status=HealthStatus.UNHEALTHY,
                    message="CUDA not available",
                    latency_ms=(time.time() - start) * 1000,
                )

            device_count = torch.cuda.device_count()
            gpu_info = []

            for i in range(device_count):
                props = torch.cuda.get_device_properties(i)
                total_mem = props.total_memory / (1024**3)
                free_mem = (props.total_memory - torch.cuda.memory_allocated(i)) / (1024**3)

                gpu_info.append({
                    "device": i,
                    "name": props.name,
                    "total_gb": round(total_mem, 2),
                    "free_gb": round(free_mem, 2),
                    "utilization_pct": round((1 - free_mem / total_mem) * 100, 1),
                })

            # Check if any GPU has less than 2GB free
            min_free = min(g["free_gb"] for g in gpu_info)
            status = HealthStatus.HEALTHY if min_free > 2 else HealthStatus.DEGRADED

            return HealthCheckResult(
                name="gpu",
                status=status,
                message=f"{device_count} GPU(s) available, {min_free:.1f}GB min free",
                latency_ms=(time.time() - start) * 1000,
                details={"gpus": gpu_info},
            )

        except Exception as e:
            return HealthCheckResult(
                name="gpu",
                status=HealthStatus.UNHEALTHY,
                message=f"GPU check failed: {e}",
                latency_ms=(time.time() - start) * 1000,
            )

    async def check_memory(self) -> HealthCheckResult:
        """Check system memory"""
        start = time.time()
        try:
            import psutil

            mem = psutil.virtual_memory()
            swap = psutil.swap_memory()

            # Degraded if less than 20% available, unhealthy if less than 10%
            if mem.percent > 90:
                status = HealthStatus.UNHEALTHY
            elif mem.percent > 80:
                status = HealthStatus.DEGRADED
            else:
                status = HealthStatus.HEALTHY

            return HealthCheckResult(
                name="memory",
                status=status,
                message=f"{mem.available / (1024**3):.1f}GB available ({100 - mem.percent:.0f}%)",
                latency_ms=(time.time() - start) * 1000,
                details={
                    "total_gb": round(mem.total / (1024**3), 2),
                    "available_gb": round(mem.available / (1024**3), 2),
                    "percent_used": mem.percent,
                    "swap_used_gb": round(swap.used / (1024**3), 2),
                },
            )

        except ImportError:
            return HealthCheckResult(
                name="memory",
                status=HealthStatus.UNKNOWN,
                message="psutil not available",
                latency_ms=(time.time() - start) * 1000,
            )

    async def check_disk(self) -> HealthCheckResult:
        """Check disk space for output directory"""
        start = time.time()
        try:
            import shutil

            output_dir = os.environ.get("VIDEO_OUTPUT_DIR", "/app/output")
            Path(output_dir).mkdir(parents=True, exist_ok=True)

            total, used, free = shutil.disk_usage(output_dir)
            percent_used = (used / total) * 100

            if percent_used > 95:
                status = HealthStatus.UNHEALTHY
            elif percent_used > 85:
                status = HealthStatus.DEGRADED
            else:
                status = HealthStatus.HEALTHY

            return HealthCheckResult(
                name="disk",
                status=status,
                message=f"{free / (1024**3):.1f}GB free ({100 - percent_used:.0f}%)",
                latency_ms=(time.time() - start) * 1000,
                details={
                    "path": output_dir,
                    "total_gb": round(total / (1024**3), 2),
                    "free_gb": round(free / (1024**3), 2),
                    "percent_used": round(percent_used, 1),
                },
            )

        except Exception as e:
            return HealthCheckResult(
                name="disk",
                status=HealthStatus.UNHEALTHY,
                message=f"Disk check failed: {e}",
                latency_ms=(time.time() - start) * 1000,
            )

    async def check_redis(self) -> HealthCheckResult:
        """Check Redis connectivity"""
        start = time.time()
        try:
            import redis

            redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
            client = redis.from_url(redis_url, socket_timeout=5)

            # Ping Redis
            client.ping()

            # Get info
            info = client.info("memory")
            used_memory_mb = info.get("used_memory", 0) / (1024 * 1024)

            return HealthCheckResult(
                name="redis",
                status=HealthStatus.HEALTHY,
                message=f"Connected, {used_memory_mb:.1f}MB used",
                latency_ms=(time.time() - start) * 1000,
                details={
                    "used_memory_mb": round(used_memory_mb, 2),
                    "connected_clients": info.get("connected_clients", 0),
                },
            )

        except ImportError:
            return HealthCheckResult(
                name="redis",
                status=HealthStatus.UNKNOWN,
                message="redis package not installed",
                latency_ms=(time.time() - start) * 1000,
            )
        except Exception as e:
            return HealthCheckResult(
                name="redis",
                status=HealthStatus.UNHEALTHY,
                message=f"Redis connection failed: {e}",
                latency_ms=(time.time() - start) * 1000,
            )

    async def check_model(self) -> HealthCheckResult:
        """Check if model is loaded and ready"""
        start = time.time()
        try:
            model_cache = os.environ.get("MODEL_CACHE_DIR", "/app/models")

            if not os.path.exists(model_cache):
                return HealthCheckResult(
                    name="model",
                    status=HealthStatus.UNHEALTHY,
                    message="Model cache directory not found",
                    latency_ms=(time.time() - start) * 1000,
                )

            # Check for model files
            model_files = list(Path(model_cache).rglob("*.safetensors"))
            model_files += list(Path(model_cache).rglob("*.bin"))
            model_files += list(Path(model_cache).rglob("*.pt"))

            if not model_files:
                return HealthCheckResult(
                    name="model",
                    status=HealthStatus.DEGRADED,
                    message="No model files found (will download on first use)",
                    latency_ms=(time.time() - start) * 1000,
                )

            total_size = sum(f.stat().st_size for f in model_files) / (1024**3)

            return HealthCheckResult(
                name="model",
                status=HealthStatus.HEALTHY,
                message=f"{len(model_files)} model files ({total_size:.1f}GB)",
                latency_ms=(time.time() - start) * 1000,
                details={
                    "model_count": len(model_files),
                    "total_size_gb": round(total_size, 2),
                },
            )

        except Exception as e:
            return HealthCheckResult(
                name="model",
                status=HealthStatus.UNKNOWN,
                message=f"Model check failed: {e}",
                latency_ms=(time.time() - start) * 1000,
            )

    async def run_all_checks(self) -> SystemHealth:
        """Run all health checks"""
        checks = await asyncio.gather(
            self.check_gpu(),
            self.check_memory(),
            self.check_disk(),
            self.check_redis(),
            self.check_model(),
            return_exceptions=True,
        )

        # Handle exceptions
        results = []
        for check in checks:
            if isinstance(check, Exception):
                results.append(HealthCheckResult(
                    name="unknown",
                    status=HealthStatus.UNHEALTHY,
                    message=str(check),
                ))
            else:
                results.append(check)

        # Determine overall status
        statuses = [c.status for c in results]
        if HealthStatus.UNHEALTHY in statuses:
            overall = HealthStatus.UNHEALTHY
        elif HealthStatus.DEGRADED in statuses:
            overall = HealthStatus.DEGRADED
        else:
            overall = HealthStatus.HEALTHY

        return SystemHealth(
            status=overall,
            checks=results,
            uptime_seconds=self.uptime,
            version=self.VERSION,
            environment=self.environment,
        )

    def set_ready(self) -> None:
        """Mark system as ready"""
        self._readiness_status = ReadinessStatus.READY
        logger.info("System marked as READY")

    def set_not_ready(self, reason: str = "") -> None:
        """Mark system as not ready"""
        self._readiness_status = ReadinessStatus.NOT_READY
        logger.warning(f"System marked as NOT READY: {reason}")

    @property
    def readiness(self) -> ReadinessStatus:
        return self._readiness_status


class InputValidator:
    """
    Comprehensive input validation for video generation.

    Validates:
    - Prompt content and length
    - Resolution and frame count
    - File paths and formats
    - Numeric ranges
    """

    # Validation limits
    MAX_PROMPT_LENGTH = 2000
    MIN_PROMPT_LENGTH = 3
    MAX_FRAMES = 200
    MIN_FRAMES = 4
    MAX_RESOLUTION = 4096
    MIN_RESOLUTION = 64
    ALLOWED_IMAGE_FORMATS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
    BLOCKED_PROMPT_PATTERNS = [
        # Add content moderation patterns here
    ]

    def validate_prompt(self, prompt: str) -> ValidationResult:
        """Validate generation prompt"""
        errors = []

        if not prompt or not prompt.strip():
            errors.append(ValidationError(
                field="prompt",
                message="Prompt cannot be empty",
                code="PROMPT_EMPTY",
            ))
        elif len(prompt) < self.MIN_PROMPT_LENGTH:
            errors.append(ValidationError(
                field="prompt",
                message=f"Prompt too short (min {self.MIN_PROMPT_LENGTH} chars)",
                code="PROMPT_TOO_SHORT",
            ))
        elif len(prompt) > self.MAX_PROMPT_LENGTH:
            errors.append(ValidationError(
                field="prompt",
                message=f"Prompt too long (max {self.MAX_PROMPT_LENGTH} chars)",
                code="PROMPT_TOO_LONG",
            ))

        return ValidationResult(valid=len(errors) == 0, errors=errors)

    def validate_resolution(self, width: int, height: int) -> ValidationResult:
        """Validate video resolution"""
        errors = []

        for name, value in [("width", width), ("height", height)]:
            if value < self.MIN_RESOLUTION:
                errors.append(ValidationError(
                    field=name,
                    message=f"{name.title()} too small (min {self.MIN_RESOLUTION}px)",
                    code=f"{name.upper()}_TOO_SMALL",
                    value=value,
                ))
            elif value > self.MAX_RESOLUTION:
                errors.append(ValidationError(
                    field=name,
                    message=f"{name.title()} too large (max {self.MAX_RESOLUTION}px)",
                    code=f"{name.upper()}_TOO_LARGE",
                    value=value,
                ))
            elif value % 8 != 0:
                errors.append(ValidationError(
                    field=name,
                    message=f"{name.title()} must be divisible by 8",
                    code=f"{name.upper()}_NOT_DIVISIBLE",
                    value=value,
                ))

        return ValidationResult(valid=len(errors) == 0, errors=errors)

    def validate_frames(self, num_frames: int) -> ValidationResult:
        """Validate frame count"""
        errors = []

        if num_frames < self.MIN_FRAMES:
            errors.append(ValidationError(
                field="num_frames",
                message=f"Frame count too low (min {self.MIN_FRAMES})",
                code="FRAMES_TOO_FEW",
                value=num_frames,
            ))
        elif num_frames > self.MAX_FRAMES:
            errors.append(ValidationError(
                field="num_frames",
                message=f"Frame count too high (max {self.MAX_FRAMES})",
                code="FRAMES_TOO_MANY",
                value=num_frames,
            ))

        return ValidationResult(valid=len(errors) == 0, errors=errors)

    def validate_image_path(self, path: str) -> ValidationResult:
        """Validate input image path"""
        errors = []

        if not path:
            return ValidationResult(valid=True)  # Optional field

        path_obj = Path(path)

        if not path_obj.exists():
            errors.append(ValidationError(
                field="image_path",
                message="Image file not found",
                code="IMAGE_NOT_FOUND",
                value=path,
            ))
        elif path_obj.suffix.lower() not in self.ALLOWED_IMAGE_FORMATS:
            errors.append(ValidationError(
                field="image_path",
                message=f"Unsupported image format. Allowed: {', '.join(self.ALLOWED_IMAGE_FORMATS)}",
                code="IMAGE_FORMAT_INVALID",
                value=path_obj.suffix,
            ))
        else:
            # Check file size (max 50MB)
            size_mb = path_obj.stat().st_size / (1024 * 1024)
            if size_mb > 50:
                errors.append(ValidationError(
                    field="image_path",
                    message="Image file too large (max 50MB)",
                    code="IMAGE_TOO_LARGE",
                    value=f"{size_mb:.1f}MB",
                ))

        return ValidationResult(valid=len(errors) == 0, errors=errors)

    def validate_generation_request(
        self,
        prompt: str,
        width: int = 1280,
        height: int = 720,
        num_frames: int = 49,
        image_path: Optional[str] = None,
    ) -> ValidationResult:
        """Validate complete generation request"""
        all_errors = []

        # Run all validations
        results = [
            self.validate_prompt(prompt),
            self.validate_resolution(width, height),
            self.validate_frames(num_frames),
            self.validate_image_path(image_path) if image_path else ValidationResult(valid=True),
        ]

        for result in results:
            all_errors.extend(result.errors)

        return ValidationResult(valid=len(all_errors) == 0, errors=all_errors)


# Global instances
health_checker = ProductionHealthChecker(
    environment=os.environ.get("ENVIRONMENT", "production")
)
input_validator = InputValidator()


async def startup_check() -> bool:
    """Run startup health checks"""
    logger.info("Running startup health checks...")

    health = await health_checker.run_all_checks()

    if health.status == HealthStatus.UNHEALTHY:
        logger.error(f"Startup health check FAILED: {health.to_dict()}")
        health_checker.set_not_ready("Health check failed")
        return False

    if health.status == HealthStatus.DEGRADED:
        logger.warning(f"Startup health check DEGRADED: {health.to_dict()}")

    health_checker.set_ready()
    logger.info(f"Startup health check PASSED: status={health.status.value}")
    return True


__all__ = [
    # Status enums
    "HealthStatus",
    "ReadinessStatus",
    # Data classes
    "HealthCheckResult",
    "SystemHealth",
    "ValidationError",
    "ValidationResult",
    # Classes
    "CircuitBreaker",
    "ProductionHealthChecker",
    "InputValidator",
    # Instances
    "health_checker",
    "input_validator",
    # Functions
    "startup_check",
]
