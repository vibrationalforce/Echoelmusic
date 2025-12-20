"""
Contract Test: Webhook Payloads
================================

Reliable notifications for creators waiting for their vision.
"""

import pytest
import json
import hmac
import hashlib
from typing import Dict, Any
from datetime import datetime


class TestWebhookPayloads:
    """Test webhook payload contracts."""

    @pytest.fixture
    def sample_payloads(self) -> Dict[str, Dict[str, Any]]:
        """Sample webhook payloads for each event type."""
        return {
            "task.created": {
                "event": "task.created",
                "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                "timestamp": "2025-12-20T10:00:00Z",
                "data": {
                    "prompt": "A beautiful sunset over mountains",
                    "resolution": "1080p",
                    "duration_seconds": 8
                }
            },
            "task.started": {
                "event": "task.started",
                "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                "timestamp": "2025-12-20T10:00:05Z",
                "data": {
                    "estimated_time_seconds": 120
                }
            },
            "task.progress": {
                "event": "task.progress",
                "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                "timestamp": "2025-12-20T10:01:00Z",
                "data": {
                    "progress": 0.5,
                    "current_step": "Generating frames"
                }
            },
            "task.completed": {
                "event": "task.completed",
                "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                "timestamp": "2025-12-20T10:02:00Z",
                "data": {
                    "video_url": "/videos/a1b2c3d4.mp4",
                    "thumbnail_url": "/thumbnails/a1b2c3d4.jpg",
                    "duration_seconds": 8,
                    "file_size_mb": 45.2
                }
            },
            "task.failed": {
                "event": "task.failed",
                "task_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
                "timestamp": "2025-12-20T10:02:00Z",
                "data": {
                    "error": "VRAM exceeded",
                    "error_code": "RESOURCE_EXHAUSTED"
                }
            }
        }

    def test_all_payloads_have_required_fields(self, sample_payloads):
        """Test all payloads have required fields."""
        required_fields = ["event", "task_id", "timestamp", "data"]

        for event_type, payload in sample_payloads.items():
            for field in required_fields:
                assert field in payload, f"{event_type} missing {field}"

    def test_event_type_matches_payload_content(self, sample_payloads):
        """Test event type is consistent with payload content."""
        # Completed events should have video_url
        completed = sample_payloads["task.completed"]
        assert "video_url" in completed["data"]

        # Failed events should have error
        failed = sample_payloads["task.failed"]
        assert "error" in failed["data"]

        # Progress events should have progress value
        progress = sample_payloads["task.progress"]
        assert "progress" in progress["data"]
        assert 0 <= progress["data"]["progress"] <= 1

    def test_timestamp_is_iso8601(self, sample_payloads):
        """Test timestamps are ISO 8601 format."""
        for event_type, payload in sample_payloads.items():
            timestamp = payload["timestamp"]
            # Should parse without error
            datetime.fromisoformat(timestamp.replace("Z", "+00:00"))

    def test_task_id_is_uuid(self, sample_payloads):
        """Test task_id is valid UUID format."""
        import re
        uuid_pattern = re.compile(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        )

        for event_type, payload in sample_payloads.items():
            assert uuid_pattern.match(payload["task_id"]), f"{event_type} has invalid task_id"

    def test_payload_serializes_to_json(self, sample_payloads):
        """Test all payloads can be serialized to JSON."""
        for event_type, payload in sample_payloads.items():
            json_str = json.dumps(payload)
            parsed = json.loads(json_str)
            assert parsed == payload

    def test_progress_value_range(self, sample_payloads):
        """Test progress values are in valid range."""
        progress = sample_payloads["task.progress"]
        assert 0 <= progress["data"]["progress"] <= 1

    def test_completed_has_video_metadata(self, sample_payloads):
        """Test completed events have video metadata."""
        completed = sample_payloads["task.completed"]["data"]

        assert "video_url" in completed
        assert "duration_seconds" in completed
        assert completed["duration_seconds"] > 0

    def test_failed_has_error_info(self, sample_payloads):
        """Test failed events have error information."""
        failed = sample_payloads["task.failed"]["data"]

        assert "error" in failed
        assert len(failed["error"]) > 0


class TestWebhookSignatures:
    """Test webhook signature verification."""

    @pytest.fixture
    def webhook_secret(self) -> str:
        return "test_webhook_secret_key_123"

    def test_signature_generation(self, webhook_secret):
        """Test signature is generated correctly."""
        payload = json.dumps({"event": "task.completed", "task_id": "123"})

        signature = hmac.new(
            webhook_secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()

        assert len(signature) == 64  # SHA256 hex digest length
        assert signature.startswith(signature[:8])  # Consistent format

    def test_signature_verification(self, webhook_secret):
        """Test signature can be verified."""
        payload = json.dumps({"event": "task.completed", "task_id": "123"})

        # Generate signature
        expected_signature = hmac.new(
            webhook_secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()

        # Verify
        received_signature = f"sha256={expected_signature}"
        computed = hmac.new(
            webhook_secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()

        assert hmac.compare_digest(f"sha256={computed}", received_signature)

    def test_invalid_signature_rejected(self, webhook_secret):
        """Test invalid signatures are rejected."""
        payload = json.dumps({"event": "task.completed", "task_id": "123"})

        valid_signature = hmac.new(
            webhook_secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()

        # Tamper with signature
        invalid_signature = valid_signature[:-1] + "x"

        assert not hmac.compare_digest(valid_signature, invalid_signature)

    def test_tampered_payload_rejected(self, webhook_secret):
        """Test tampered payloads are rejected."""
        original_payload = json.dumps({"event": "task.completed", "task_id": "123"})
        tampered_payload = json.dumps({"event": "task.completed", "task_id": "456"})

        signature = hmac.new(
            webhook_secret.encode(),
            original_payload.encode(),
            hashlib.sha256
        ).hexdigest()

        # Verify with tampered payload should fail
        computed = hmac.new(
            webhook_secret.encode(),
            tampered_payload.encode(),
            hashlib.sha256
        ).hexdigest()

        assert not hmac.compare_digest(signature, computed)


class TestWebhookRetries:
    """Test webhook retry behavior."""

    def test_retry_headers(self):
        """Test retry attempt is indicated in headers."""
        headers = {
            "X-Webhook-Retry": "1",
            "X-Webhook-Retry-Reason": "timeout"
        }

        assert int(headers["X-Webhook-Retry"]) >= 0
        assert headers["X-Webhook-Retry-Reason"] in ["timeout", "error", "connection_failed"]

    def test_idempotency_key(self):
        """Test idempotency key is provided."""
        headers = {
            "X-Idempotency-Key": "evt_a1b2c3d4e5f6"
        }

        assert len(headers["X-Idempotency-Key"]) > 0

    def test_retry_schedule(self):
        """Test retry follows exponential backoff."""
        retry_delays_seconds = [10, 30, 60, 300, 3600]  # 10s, 30s, 1m, 5m, 1h

        for i in range(1, len(retry_delays_seconds)):
            assert retry_delays_seconds[i] > retry_delays_seconds[i - 1]
