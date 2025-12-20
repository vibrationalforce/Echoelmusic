"""
Layer 4: Deployment & API Client
- Docker/Docker Compose configuration
- Client library with WebSocket support
- CLI interface
- Production deployment utilities
- Production readiness checks and validation
- SLA Monitoring and Enforcement
"""

from ..client import VideoGenClient, SyncVideoGenClient, GenerationResult, TaskStatus
from .production_ready import (
    HealthStatus,
    ReadinessStatus,
    HealthCheckResult,
    SystemHealth,
    ValidationError,
    ValidationResult,
    CircuitBreaker,
    ProductionHealthChecker,
    InputValidator,
    health_checker,
    input_validator,
    startup_check,
    SLALevel,
    SLATarget,
    SLAMetrics,
    SLAViolation,
    SLAMonitor,
    sla_monitor,
)

__all__ = [
    # Client
    "VideoGenClient",
    "SyncVideoGenClient",
    "GenerationResult",
    "TaskStatus",
    # Production Readiness
    "HealthStatus",
    "ReadinessStatus",
    "HealthCheckResult",
    "SystemHealth",
    "ValidationError",
    "ValidationResult",
    "CircuitBreaker",
    "ProductionHealthChecker",
    "InputValidator",
    "health_checker",
    "input_validator",
    "startup_check",
    # SLA Monitoring
    "SLALevel",
    "SLATarget",
    "SLAMetrics",
    "SLAViolation",
    "SLAMonitor",
    "sla_monitor",
]
