"""
API Key Authentication
======================

API key generation and validation for programmatic access.
"""

import os
import secrets
import hashlib
import hmac
from typing import Optional, Tuple
from datetime import datetime

from fastapi import HTTPException, Security, Depends
from fastapi.security import APIKeyHeader

# API Key header name
API_KEY_HEADER = "X-API-Key"
API_KEY_PREFIX_LIVE = "sk_live_"
API_KEY_PREFIX_TEST = "sk_test_"

api_key_header = APIKeyHeader(name=API_KEY_HEADER, auto_error=False)


class APIKeyAuth:
    """API Key authentication handler."""

    def __init__(self, auto_error: bool = True):
        self.auto_error = auto_error

    async def __call__(self, api_key: str = Security(api_key_header)) -> Optional[dict]:
        if not api_key:
            if self.auto_error:
                raise HTTPException(
                    status_code=401,
                    detail="API key required",
                    headers={"WWW-Authenticate": "ApiKey"}
                )
            return None

        # Validate format
        if not self._is_valid_format(api_key):
            raise HTTPException(status_code=401, detail="Invalid API key format")

        # Verify against database
        key_data = await self._verify_key(api_key)

        if not key_data:
            raise HTTPException(status_code=401, detail="Invalid API key")

        if not key_data.get("is_active", False):
            raise HTTPException(status_code=401, detail="API key is inactive")

        # Check expiration
        expires_at = key_data.get("expires_at")
        if expires_at and datetime.fromisoformat(expires_at) < datetime.utcnow():
            raise HTTPException(status_code=401, detail="API key has expired")

        return key_data

    def _is_valid_format(self, api_key: str) -> bool:
        """Check if API key has valid format."""
        return (
            api_key.startswith(API_KEY_PREFIX_LIVE) or
            api_key.startswith(API_KEY_PREFIX_TEST)
        ) and len(api_key) >= 32

    async def _verify_key(self, api_key: str) -> Optional[dict]:
        """Verify API key against database."""
        # Extract prefix for lookup
        prefix = api_key[:20]
        key_hash = hash_api_key(api_key)

        # In production, query database
        # SELECT * FROM api_keys WHERE key_prefix = prefix AND key_hash = key_hash
        # Placeholder
        return None


def generate_api_key(is_live: bool = True) -> Tuple[str, str]:
    """
    Generate a new API key.

    Returns:
        Tuple of (plain_key, key_hash)
        Only return plain_key to user ONCE, store key_hash in database
    """
    prefix = API_KEY_PREFIX_LIVE if is_live else API_KEY_PREFIX_TEST
    random_part = secrets.token_urlsafe(32)
    plain_key = f"{prefix}{random_part}"
    key_hash = hash_api_key(plain_key)

    return plain_key, key_hash


def hash_api_key(api_key: str) -> str:
    """
    Hash an API key for storage.
    Uses SHA-256 for one-way hashing.
    """
    return hashlib.sha256(api_key.encode()).hexdigest()


def verify_api_key(plain_key: str, stored_hash: str) -> bool:
    """
    Verify an API key against stored hash.
    Uses constant-time comparison to prevent timing attacks.
    """
    computed_hash = hash_api_key(plain_key)
    return hmac.compare_digest(computed_hash, stored_hash)


def get_key_prefix(api_key: str) -> str:
    """Extract the prefix portion of an API key for lookup."""
    # Return first 20 chars (prefix + some random)
    return api_key[:20] if len(api_key) >= 20 else api_key


def is_test_key(api_key: str) -> bool:
    """Check if API key is a test key."""
    return api_key.startswith(API_KEY_PREFIX_TEST)


def is_live_key(api_key: str) -> bool:
    """Check if API key is a live/production key."""
    return api_key.startswith(API_KEY_PREFIX_LIVE)


class APIKeyService:
    """Service for managing API keys."""

    async def create_key(
        self,
        user_id: str,
        name: str = None,
        scopes: list = None,
        expires_in_days: int = None,
        is_live: bool = True
    ) -> dict:
        """Create a new API key for a user."""
        plain_key, key_hash = generate_api_key(is_live)

        # Store in database
        key_data = {
            "user_id": user_id,
            "key_hash": key_hash,
            "key_prefix": get_key_prefix(plain_key),
            "name": name or "Default",
            "scopes": scopes or [],
            "is_active": True,
            "expires_at": None,  # Set if expires_in_days provided
        }

        # In production, insert into database
        # INSERT INTO api_keys ...

        return {
            "key": plain_key,  # Only shown once!
            "prefix": key_data["key_prefix"],
            "name": key_data["name"],
            "created_at": datetime.utcnow().isoformat()
        }

    async def revoke_key(self, user_id: str, key_prefix: str) -> bool:
        """Revoke an API key."""
        # UPDATE api_keys SET is_active = false WHERE user_id = ? AND key_prefix = ?
        return True

    async def list_keys(self, user_id: str) -> list:
        """List all API keys for a user (without the actual keys)."""
        # SELECT key_prefix, name, created_at, last_used_at FROM api_keys WHERE user_id = ?
        return []


# Global API key service instance
api_key_service = APIKeyService()
