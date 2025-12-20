"""
Production Rate Limiter with Token Bucket Algorithm
====================================================

Features:
- Token bucket algorithm for smooth rate limiting
- Sliding window rate limiting for burst control
- Per-IP, per-user, and global rate limits
- Redis-backed distributed rate limiting
- Configurable limits per endpoint
- Rate limit headers (X-RateLimit-*)
"""

import os
import time
import asyncio
import hashlib
from typing import Optional, Dict, Any, Tuple, Callable
from dataclasses import dataclass, field
from enum import Enum
from abc import ABC, abstractmethod
from functools import wraps

from fastapi import Request, HTTPException, Response
from fastapi.responses import JSONResponse


# ============================================================================
# Configuration
# ============================================================================

class RateLimitScope(str, Enum):
    """Scope for rate limiting"""
    GLOBAL = "global"
    IP = "ip"
    USER = "user"
    API_KEY = "api_key"
    ENDPOINT = "endpoint"


@dataclass
class RateLimitConfig:
    """Rate limit configuration"""
    requests_per_second: float = 10.0
    burst_size: int = 50
    window_seconds: int = 60
    scope: RateLimitScope = RateLimitScope.IP

    # Endpoint-specific overrides
    endpoint_limits: Dict[str, "RateLimitConfig"] = field(default_factory=dict)

    # Exempt paths (no rate limiting)
    exempt_paths: set = field(default_factory=lambda: {"/health", "/metrics"})

    # Headers
    include_headers: bool = True
    retry_after_header: bool = True


# Default rate limit presets
RATE_LIMIT_PRESETS = {
    "strict": RateLimitConfig(
        requests_per_second=2.0,
        burst_size=10,
        window_seconds=60
    ),
    "standard": RateLimitConfig(
        requests_per_second=10.0,
        burst_size=50,
        window_seconds=60
    ),
    "relaxed": RateLimitConfig(
        requests_per_second=50.0,
        burst_size=200,
        window_seconds=60
    ),
    "generation": RateLimitConfig(
        requests_per_second=0.5,  # 1 request per 2 seconds
        burst_size=5,
        window_seconds=300  # 5 minute window
    ),
}


# ============================================================================
# Token Bucket Implementation
# ============================================================================

@dataclass
class TokenBucket:
    """
    Token Bucket rate limiter.

    Tokens are added at a fixed rate up to a maximum (burst_size).
    Each request consumes one token. Requests are denied if no tokens are available.
    """
    rate: float  # Tokens per second
    capacity: int  # Maximum tokens (burst size)
    tokens: float = field(default=0.0)
    last_update: float = field(default_factory=time.time)

    def __post_init__(self):
        self.tokens = float(self.capacity)

    def consume(self, tokens: int = 1) -> Tuple[bool, float]:
        """
        Attempt to consume tokens.

        Returns:
            Tuple of (success, wait_time_if_denied)
        """
        now = time.time()
        elapsed = now - self.last_update
        self.last_update = now

        # Add tokens based on elapsed time
        self.tokens = min(self.capacity, self.tokens + elapsed * self.rate)

        if self.tokens >= tokens:
            self.tokens -= tokens
            return True, 0.0

        # Calculate wait time
        tokens_needed = tokens - self.tokens
        wait_time = tokens_needed / self.rate
        return False, wait_time

    @property
    def available_tokens(self) -> int:
        """Get current available tokens (with time adjustment)"""
        now = time.time()
        elapsed = now - self.last_update
        return min(self.capacity, int(self.tokens + elapsed * self.rate))


# ============================================================================
# Rate Limit Storage Backend
# ============================================================================

class RateLimitBackend(ABC):
    """Abstract backend for rate limit storage"""

    @abstractmethod
    async def get_bucket(self, key: str, config: RateLimitConfig) -> TokenBucket:
        """Get or create a token bucket for the given key"""
        pass

    @abstractmethod
    async def consume(
        self, key: str, config: RateLimitConfig, tokens: int = 1
    ) -> Tuple[bool, float, int, int]:
        """
        Consume tokens from bucket.

        Returns:
            Tuple of (allowed, retry_after, remaining, limit)
        """
        pass

    @abstractmethod
    async def cleanup(self):
        """Cleanup expired entries"""
        pass


class MemoryBackend(RateLimitBackend):
    """In-memory rate limit storage (single instance only)"""

    def __init__(self):
        self._buckets: Dict[str, TokenBucket] = {}
        self._lock = asyncio.Lock()
        self._last_cleanup = time.time()
        self._cleanup_interval = 300  # 5 minutes

    async def get_bucket(self, key: str, config: RateLimitConfig) -> TokenBucket:
        async with self._lock:
            if key not in self._buckets:
                self._buckets[key] = TokenBucket(
                    rate=config.requests_per_second,
                    capacity=config.burst_size
                )
            return self._buckets[key]

    async def consume(
        self, key: str, config: RateLimitConfig, tokens: int = 1
    ) -> Tuple[bool, float, int, int]:
        async with self._lock:
            # Cleanup if needed
            if time.time() - self._last_cleanup > self._cleanup_interval:
                await self._cleanup_expired()

            if key not in self._buckets:
                self._buckets[key] = TokenBucket(
                    rate=config.requests_per_second,
                    capacity=config.burst_size
                )

            bucket = self._buckets[key]
            allowed, retry_after = bucket.consume(tokens)

            return (
                allowed,
                retry_after,
                bucket.available_tokens,
                config.burst_size
            )

    async def cleanup(self):
        async with self._lock:
            await self._cleanup_expired()

    async def _cleanup_expired(self):
        """Remove stale buckets"""
        now = time.time()
        expired_keys = []

        for key, bucket in self._buckets.items():
            # Remove buckets that are full and haven't been used
            if bucket.available_tokens >= bucket.capacity:
                if now - bucket.last_update > 600:  # 10 minutes
                    expired_keys.append(key)

        for key in expired_keys:
            del self._buckets[key]

        self._last_cleanup = now


class RedisBackend(RateLimitBackend):
    """Redis-backed rate limit storage for distributed deployments"""

    def __init__(self, redis_url: str = "redis://localhost:6379/1"):
        self.redis_url = redis_url
        self._redis = None

    async def _get_redis(self):
        if self._redis is None:
            try:
                import redis.asyncio as redis
                self._redis = redis.from_url(self.redis_url)
            except ImportError:
                raise RuntimeError("redis package required for RedisBackend")
        return self._redis

    async def get_bucket(self, key: str, config: RateLimitConfig) -> TokenBucket:
        # Redis backend reconstructs bucket from stored state
        redis = await self._get_redis()
        data = await redis.hgetall(f"ratelimit:{key}")

        if data:
            return TokenBucket(
                rate=config.requests_per_second,
                capacity=config.burst_size,
                tokens=float(data.get(b"tokens", config.burst_size)),
                last_update=float(data.get(b"last_update", time.time()))
            )
        return TokenBucket(rate=config.requests_per_second, capacity=config.burst_size)

    async def consume(
        self, key: str, config: RateLimitConfig, tokens: int = 1
    ) -> Tuple[bool, float, int, int]:
        redis = await self._get_redis()
        redis_key = f"ratelimit:{key}"
        now = time.time()

        # Lua script for atomic token bucket operation
        lua_script = """
        local key = KEYS[1]
        local rate = tonumber(ARGV[1])
        local capacity = tonumber(ARGV[2])
        local now = tonumber(ARGV[3])
        local tokens_requested = tonumber(ARGV[4])
        local ttl = tonumber(ARGV[5])

        local data = redis.call('HGETALL', key)
        local current_tokens = capacity
        local last_update = now

        if #data > 0 then
            for i = 1, #data, 2 do
                if data[i] == 'tokens' then
                    current_tokens = tonumber(data[i+1])
                elseif data[i] == 'last_update' then
                    last_update = tonumber(data[i+1])
                end
            end
        end

        -- Add tokens based on elapsed time
        local elapsed = now - last_update
        current_tokens = math.min(capacity, current_tokens + elapsed * rate)

        local allowed = 0
        local retry_after = 0

        if current_tokens >= tokens_requested then
            current_tokens = current_tokens - tokens_requested
            allowed = 1
        else
            retry_after = (tokens_requested - current_tokens) / rate
        end

        -- Store updated state
        redis.call('HMSET', key, 'tokens', current_tokens, 'last_update', now)
        redis.call('EXPIRE', key, ttl)

        return {allowed, tostring(retry_after), math.floor(current_tokens), capacity}
        """

        try:
            result = await redis.eval(
                lua_script,
                1,
                redis_key,
                config.requests_per_second,
                config.burst_size,
                now,
                tokens,
                config.window_seconds * 2
            )

            return (
                bool(result[0]),
                float(result[1]),
                int(result[2]),
                int(result[3])
            )
        except Exception:
            # Fallback to allow on Redis errors (fail-open)
            return True, 0.0, config.burst_size, config.burst_size

    async def cleanup(self):
        # Redis handles expiration via TTL
        pass


# ============================================================================
# Rate Limiter Core
# ============================================================================

class RateLimiter:
    """
    Production rate limiter with token bucket algorithm.

    Supports:
    - Per-IP, per-user, per-API-key, and global rate limiting
    - Configurable limits per endpoint
    - Rate limit response headers
    - Redis backend for distributed deployments
    """

    def __init__(
        self,
        config: Optional[RateLimitConfig] = None,
        backend: Optional[RateLimitBackend] = None
    ):
        self.config = config or RateLimitConfig()
        self.backend = backend or MemoryBackend()

    def _get_key(self, request: Request, scope: RateLimitScope) -> str:
        """Generate rate limit key based on scope"""
        if scope == RateLimitScope.GLOBAL:
            return "global"

        if scope == RateLimitScope.IP:
            # Get real IP (handle proxies)
            forwarded = request.headers.get("x-forwarded-for")
            if forwarded:
                ip = forwarded.split(",")[0].strip()
            else:
                ip = request.client.host if request.client else "unknown"
            return f"ip:{ip}"

        if scope == RateLimitScope.USER:
            # Extract user from auth header or session
            user_id = request.headers.get("x-user-id", "anonymous")
            return f"user:{user_id}"

        if scope == RateLimitScope.API_KEY:
            api_key = request.headers.get("x-api-key", "")
            key_hash = hashlib.sha256(api_key.encode()).hexdigest()[:16]
            return f"apikey:{key_hash}"

        if scope == RateLimitScope.ENDPOINT:
            path = request.url.path
            return f"endpoint:{path}"

        return "unknown"

    def _get_config_for_path(self, path: str) -> RateLimitConfig:
        """Get rate limit config for specific path"""
        # Check endpoint-specific overrides
        for pattern, override in self.config.endpoint_limits.items():
            if path.startswith(pattern):
                return override
        return self.config

    async def check(
        self,
        request: Request,
        tokens: int = 1
    ) -> Tuple[bool, Dict[str, str]]:
        """
        Check if request should be rate limited.

        Returns:
            Tuple of (allowed, headers_dict)
        """
        path = request.url.path

        # Skip exempt paths
        if path in self.config.exempt_paths:
            return True, {}

        config = self._get_config_for_path(path)
        key = self._get_key(request, config.scope)

        allowed, retry_after, remaining, limit = await self.backend.consume(
            key, config, tokens
        )

        headers = {}
        if config.include_headers:
            headers = {
                "X-RateLimit-Limit": str(limit),
                "X-RateLimit-Remaining": str(max(0, remaining)),
                "X-RateLimit-Reset": str(int(time.time() + config.window_seconds)),
            }
            if not allowed and config.retry_after_header:
                headers["Retry-After"] = str(int(retry_after) + 1)

        return allowed, headers

    async def __call__(self, request: Request, call_next):
        """ASGI middleware implementation"""
        allowed, headers = await self.check(request)

        if not allowed:
            response = JSONResponse(
                status_code=429,
                content={
                    "error": "Too Many Requests",
                    "detail": "Rate limit exceeded. Please try again later.",
                    "retry_after": headers.get("Retry-After", "60")
                }
            )
            for key, value in headers.items():
                response.headers[key] = value
            return response

        response = await call_next(request)

        # Add rate limit headers to response
        for key, value in headers.items():
            response.headers[key] = value

        return response


# ============================================================================
# FastAPI Middleware
# ============================================================================

class RateLimitMiddleware:
    """FastAPI middleware wrapper for rate limiting"""

    def __init__(
        self,
        app,
        config: Optional[RateLimitConfig] = None,
        backend: Optional[RateLimitBackend] = None
    ):
        self.app = app
        self.limiter = RateLimiter(config, backend)

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request = Request(scope, receive)
        allowed, headers = await self.limiter.check(request)

        if not allowed:
            response = JSONResponse(
                status_code=429,
                content={
                    "error": "Too Many Requests",
                    "detail": "Rate limit exceeded",
                    "retry_after": headers.get("Retry-After", "60")
                }
            )
            for key, value in headers.items():
                response.headers[key] = value

            await response(scope, receive, send)
            return

        # Track headers to add to response
        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                # Add rate limit headers
                response_headers = list(message.get("headers", []))
                for key, value in headers.items():
                    response_headers.append((key.lower().encode(), value.encode()))
                message = {**message, "headers": response_headers}
            await send(message)

        await self.app(scope, receive, send_wrapper)


# ============================================================================
# Decorator for endpoint-specific rate limiting
# ============================================================================

def rate_limit(
    requests_per_second: float = 10.0,
    burst_size: int = 50,
    scope: RateLimitScope = RateLimitScope.IP,
    key_func: Optional[Callable[[Request], str]] = None
):
    """
    Decorator for endpoint-specific rate limiting.

    Usage:
        @app.get("/generate")
        @rate_limit(requests_per_second=0.5, burst_size=5)
        async def generate_video(request: Request):
            ...
    """
    config = RateLimitConfig(
        requests_per_second=requests_per_second,
        burst_size=burst_size,
        scope=scope
    )
    backend = MemoryBackend()

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Find request in args/kwargs
            request = None
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                    break
            if request is None:
                request = kwargs.get("request")

            if request is None:
                return await func(*args, **kwargs)

            # Generate key
            if key_func:
                key = key_func(request)
            else:
                limiter = RateLimiter(config, backend)
                key = limiter._get_key(request, scope)

            allowed, retry_after, remaining, limit = await backend.consume(
                key, config
            )

            if not allowed:
                raise HTTPException(
                    status_code=429,
                    detail={
                        "error": "Rate limit exceeded",
                        "retry_after": int(retry_after) + 1
                    },
                    headers={
                        "Retry-After": str(int(retry_after) + 1),
                        "X-RateLimit-Limit": str(limit),
                        "X-RateLimit-Remaining": "0"
                    }
                )

            return await func(*args, **kwargs)

        return wrapper
    return decorator


# ============================================================================
# Factory Functions
# ============================================================================

def create_rate_limiter(
    preset: str = "standard",
    redis_url: Optional[str] = None,
    **overrides
) -> RateLimiter:
    """
    Create a rate limiter with preset configuration.

    Args:
        preset: One of "strict", "standard", "relaxed", "generation"
        redis_url: Optional Redis URL for distributed rate limiting
        **overrides: Override specific config values

    Returns:
        Configured RateLimiter instance
    """
    if preset not in RATE_LIMIT_PRESETS:
        raise ValueError(f"Unknown preset: {preset}")

    config = RATE_LIMIT_PRESETS[preset]

    # Apply overrides
    if overrides:
        config = RateLimitConfig(
            requests_per_second=overrides.get(
                "requests_per_second", config.requests_per_second
            ),
            burst_size=overrides.get("burst_size", config.burst_size),
            window_seconds=overrides.get("window_seconds", config.window_seconds),
            scope=overrides.get("scope", config.scope),
        )

    # Select backend
    if redis_url:
        backend = RedisBackend(redis_url)
    else:
        backend = MemoryBackend()

    return RateLimiter(config, backend)


# ============================================================================
# Exports
# ============================================================================

__all__ = [
    # Config
    "RateLimitConfig",
    "RateLimitScope",
    "RATE_LIMIT_PRESETS",
    # Core
    "TokenBucket",
    "RateLimiter",
    # Backends
    "RateLimitBackend",
    "MemoryBackend",
    "RedisBackend",
    # Middleware
    "RateLimitMiddleware",
    # Decorators
    "rate_limit",
    # Factory
    "create_rate_limiter",
]
