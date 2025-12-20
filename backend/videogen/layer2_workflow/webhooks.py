"""
Webhook Notification System
============================

Features:
- Async webhook delivery with retries
- Payload signing with HMAC-SHA256
- Configurable retry policy with exponential backoff
- Webhook event types for all task states
- Dead letter queue for failed deliveries
- Webhook validation and security
"""

import os
import hmac
import json
import time
import asyncio
import hashlib
import logging
from typing import Optional, Dict, Any, List, Callable
from dataclasses import dataclass, field, asdict
from enum import Enum
from datetime import datetime
from abc import ABC, abstractmethod

import httpx


# ============================================================================
# Configuration
# ============================================================================

class WebhookEvent(str, Enum):
    """Webhook event types"""
    TASK_CREATED = "task.created"
    TASK_STARTED = "task.started"
    TASK_PROGRESS = "task.progress"
    TASK_COMPLETED = "task.completed"
    TASK_FAILED = "task.failed"
    TASK_CANCELLED = "task.cancelled"
    BATCH_COMPLETED = "batch.completed"


@dataclass
class WebhookConfig:
    """Webhook delivery configuration"""
    # Retry settings
    max_retries: int = 3
    retry_delays: List[float] = field(
        default_factory=lambda: [1.0, 5.0, 30.0]  # Exponential backoff
    )
    timeout_seconds: float = 30.0

    # Security
    sign_payloads: bool = True
    signature_header: str = "X-Webhook-Signature"
    timestamp_header: str = "X-Webhook-Timestamp"

    # Headers
    user_agent: str = "Echoelmusic-Webhook/1.0"
    content_type: str = "application/json"

    # Dead letter queue
    enable_dlq: bool = True
    dlq_path: str = "/tmp/videogen/webhook_dlq"


@dataclass
class WebhookPayload:
    """Webhook payload structure"""
    event: str
    task_id: str
    timestamp: str
    data: Dict[str, Any]
    version: str = "1.0"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "event": self.event,
            "task_id": self.task_id,
            "timestamp": self.timestamp,
            "data": self.data,
            "version": self.version,
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), default=str, ensure_ascii=False)


@dataclass
class WebhookDeliveryResult:
    """Result of webhook delivery attempt"""
    success: bool
    url: str
    status_code: Optional[int] = None
    response_body: Optional[str] = None
    error: Optional[str] = None
    attempts: int = 1
    total_time_ms: float = 0.0


# ============================================================================
# Webhook Client
# ============================================================================

class WebhookClient:
    """
    Async webhook client with retry logic and payload signing.

    Features:
    - HMAC-SHA256 signature for payload verification
    - Exponential backoff retry policy
    - Async HTTP delivery with timeout
    - Dead letter queue for failed webhooks
    """

    def __init__(
        self,
        config: Optional[WebhookConfig] = None,
        secret_key: Optional[str] = None
    ):
        self.config = config or WebhookConfig()
        self.secret_key = secret_key or os.environ.get(
            "WEBHOOK_SECRET_KEY",
            "echoelmusic-webhook-secret-change-in-production"
        )
        self._client: Optional[httpx.AsyncClient] = None
        self._dlq: List[Dict] = []

    async def _get_client(self) -> httpx.AsyncClient:
        """Get or create HTTP client"""
        if self._client is None or self._client.is_closed:
            self._client = httpx.AsyncClient(
                timeout=httpx.Timeout(self.config.timeout_seconds),
                follow_redirects=True,
                http2=True,
            )
        return self._client

    async def close(self):
        """Close HTTP client"""
        if self._client:
            await self._client.aclose()
            self._client = None

    def _sign_payload(self, payload: str, timestamp: str) -> str:
        """
        Generate HMAC-SHA256 signature for payload verification.

        Signature format: t={timestamp},v1={signature}
        """
        message = f"{timestamp}.{payload}"
        signature = hmac.new(
            self.secret_key.encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()
        return f"t={timestamp},v1={signature}"

    async def deliver(
        self,
        url: str,
        payload: WebhookPayload,
    ) -> WebhookDeliveryResult:
        """
        Deliver webhook with retry logic.

        Args:
            url: Webhook endpoint URL
            payload: Webhook payload to deliver

        Returns:
            WebhookDeliveryResult with delivery status
        """
        if not url or not url.startswith(("http://", "https://")):
            return WebhookDeliveryResult(
                success=False,
                url=url,
                error="Invalid webhook URL"
            )

        start_time = time.perf_counter()
        payload_json = payload.to_json()
        timestamp = str(int(time.time()))
        attempts = 0
        last_error = None
        last_status = None

        # Build headers
        headers = {
            "Content-Type": self.config.content_type,
            "User-Agent": self.config.user_agent,
            self.config.timestamp_header: timestamp,
            "X-Webhook-Event": payload.event,
            "X-Webhook-Task-ID": payload.task_id,
        }

        if self.config.sign_payloads:
            signature = self._sign_payload(payload_json, timestamp)
            headers[self.config.signature_header] = signature

        client = await self._get_client()

        # Retry loop
        for attempt in range(self.config.max_retries + 1):
            attempts = attempt + 1

            try:
                response = await client.post(
                    url,
                    content=payload_json,
                    headers=headers,
                )

                last_status = response.status_code

                # Success: 2xx status codes
                if 200 <= response.status_code < 300:
                    return WebhookDeliveryResult(
                        success=True,
                        url=url,
                        status_code=response.status_code,
                        response_body=response.text[:1000],
                        attempts=attempts,
                        total_time_ms=(time.perf_counter() - start_time) * 1000
                    )

                # Client error: don't retry 4xx except 429
                if 400 <= response.status_code < 500 and response.status_code != 429:
                    last_error = f"Client error: {response.status_code}"
                    break

                # Server error or rate limited: retry
                last_error = f"Server error: {response.status_code}"

            except httpx.TimeoutException:
                last_error = "Request timeout"
            except httpx.ConnectError:
                last_error = "Connection failed"
            except Exception as e:
                last_error = str(e)

            # Wait before retry (if not last attempt)
            if attempt < self.config.max_retries:
                delay = self.config.retry_delays[
                    min(attempt, len(self.config.retry_delays) - 1)
                ]
                await asyncio.sleep(delay)

        # All retries failed
        result = WebhookDeliveryResult(
            success=False,
            url=url,
            status_code=last_status,
            error=last_error,
            attempts=attempts,
            total_time_ms=(time.perf_counter() - start_time) * 1000
        )

        # Add to dead letter queue
        if self.config.enable_dlq:
            await self._add_to_dlq(url, payload, result)

        return result

    async def _add_to_dlq(
        self,
        url: str,
        payload: WebhookPayload,
        result: WebhookDeliveryResult
    ):
        """Add failed webhook to dead letter queue"""
        entry = {
            "url": url,
            "payload": payload.to_dict(),
            "error": result.error,
            "attempts": result.attempts,
            "failed_at": datetime.utcnow().isoformat(),
        }
        self._dlq.append(entry)

        # Optionally persist to file
        try:
            import os
            os.makedirs(self.config.dlq_path, exist_ok=True)
            filename = f"{self.config.dlq_path}/{payload.task_id}_{int(time.time())}.json"
            with open(filename, "w") as f:
                json.dump(entry, f, default=str)
        except Exception:
            pass  # Best effort persistence

    async def retry_dlq(self) -> List[WebhookDeliveryResult]:
        """Retry all items in dead letter queue"""
        results = []

        for entry in self._dlq[:]:  # Copy to allow modification
            payload = WebhookPayload(**entry["payload"])
            result = await self.deliver(entry["url"], payload)

            if result.success:
                self._dlq.remove(entry)

            results.append(result)

        return results


# ============================================================================
# Webhook Manager
# ============================================================================

class WebhookManager:
    """
    High-level webhook management for task lifecycle events.

    Handles:
    - Webhook URL storage per task
    - Event filtering
    - Async delivery with fire-and-forget option
    """

    def __init__(self, client: Optional[WebhookClient] = None):
        self.client = client or WebhookClient()
        self._task_webhooks: Dict[str, str] = {}  # task_id -> webhook_url
        self._event_handlers: Dict[WebhookEvent, List[Callable]] = {}

    def register_webhook(self, task_id: str, webhook_url: str):
        """Register webhook URL for a task"""
        if webhook_url:
            self._task_webhooks[task_id] = webhook_url

    def unregister_webhook(self, task_id: str):
        """Remove webhook registration"""
        self._task_webhooks.pop(task_id, None)

    def on_event(self, event: WebhookEvent):
        """Decorator to register event handler"""
        def decorator(func: Callable) -> Callable:
            if event not in self._event_handlers:
                self._event_handlers[event] = []
            self._event_handlers[event].append(func)
            return func
        return decorator

    async def notify(
        self,
        task_id: str,
        event: WebhookEvent,
        data: Dict[str, Any],
        wait: bool = False
    ) -> Optional[WebhookDeliveryResult]:
        """
        Send webhook notification for task event.

        Args:
            task_id: Task identifier
            event: Event type
            data: Event data
            wait: If True, wait for delivery result. If False, fire-and-forget.

        Returns:
            WebhookDeliveryResult if wait=True, else None
        """
        webhook_url = self._task_webhooks.get(task_id)
        if not webhook_url:
            return None

        payload = WebhookPayload(
            event=event.value,
            task_id=task_id,
            timestamp=datetime.utcnow().isoformat() + "Z",
            data=data,
        )

        # Trigger local event handlers
        if event in self._event_handlers:
            for handler in self._event_handlers[event]:
                try:
                    await handler(task_id, event, data)
                except Exception:
                    pass  # Don't let handlers block delivery

        if wait:
            return await self.client.deliver(webhook_url, payload)
        else:
            # Fire and forget
            asyncio.create_task(self.client.deliver(webhook_url, payload))
            return None

    async def notify_task_created(
        self,
        task_id: str,
        webhook_url: str,
        request_data: Dict[str, Any]
    ):
        """Notify that a task was created"""
        self.register_webhook(task_id, webhook_url)
        await self.notify(
            task_id,
            WebhookEvent.TASK_CREATED,
            {"request": request_data}
        )

    async def notify_task_started(self, task_id: str):
        """Notify that task processing started"""
        await self.notify(
            task_id,
            WebhookEvent.TASK_STARTED,
            {"started_at": datetime.utcnow().isoformat()}
        )

    async def notify_task_progress(
        self,
        task_id: str,
        progress: float,
        step: str
    ):
        """Notify task progress update"""
        await self.notify(
            task_id,
            WebhookEvent.TASK_PROGRESS,
            {"progress": progress, "step": step}
        )

    async def notify_task_completed(
        self,
        task_id: str,
        result: Dict[str, Any]
    ):
        """Notify that task completed successfully"""
        await self.notify(
            task_id,
            WebhookEvent.TASK_COMPLETED,
            {"result": result, "completed_at": datetime.utcnow().isoformat()},
            wait=True  # Wait for completion notifications
        )
        self.unregister_webhook(task_id)

    async def notify_task_failed(
        self,
        task_id: str,
        error: str
    ):
        """Notify that task failed"""
        await self.notify(
            task_id,
            WebhookEvent.TASK_FAILED,
            {"error": error, "failed_at": datetime.utcnow().isoformat()},
            wait=True
        )
        self.unregister_webhook(task_id)

    async def close(self):
        """Cleanup resources"""
        await self.client.close()


# ============================================================================
# Signature Verification (for webhook receivers)
# ============================================================================

def verify_webhook_signature(
    payload: str,
    signature_header: str,
    secret_key: str,
    tolerance_seconds: int = 300
) -> bool:
    """
    Verify webhook signature for incoming webhooks.

    Usage (in receiving endpoint):
        signature = request.headers.get("X-Webhook-Signature")
        if not verify_webhook_signature(body, signature, SECRET_KEY):
            raise HTTPException(401, "Invalid signature")

    Args:
        payload: Raw request body
        signature_header: Value of X-Webhook-Signature header
        secret_key: Shared secret key
        tolerance_seconds: Maximum age of signature (replay attack prevention)

    Returns:
        True if signature is valid
    """
    if not signature_header:
        return False

    # Parse signature header: t={timestamp},v1={signature}
    parts = {}
    for item in signature_header.split(","):
        if "=" in item:
            key, value = item.split("=", 1)
            parts[key.strip()] = value.strip()

    timestamp = parts.get("t")
    signature = parts.get("v1")

    if not timestamp or not signature:
        return False

    # Check timestamp (prevent replay attacks)
    try:
        sig_time = int(timestamp)
        current_time = int(time.time())
        if abs(current_time - sig_time) > tolerance_seconds:
            return False
    except ValueError:
        return False

    # Verify signature
    expected_message = f"{timestamp}.{payload}"
    expected_signature = hmac.new(
        secret_key.encode(),
        expected_message.encode(),
        hashlib.sha256
    ).hexdigest()

    return hmac.compare_digest(signature, expected_signature)


# ============================================================================
# Global Instance
# ============================================================================

# Global webhook manager
webhook_manager = WebhookManager()


# ============================================================================
# Exports
# ============================================================================

__all__ = [
    # Config
    "WebhookConfig",
    "WebhookEvent",
    # Payload
    "WebhookPayload",
    "WebhookDeliveryResult",
    # Client
    "WebhookClient",
    "WebhookManager",
    "webhook_manager",
    # Verification
    "verify_webhook_signature",
]
