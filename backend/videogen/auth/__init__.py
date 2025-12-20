"""
Authentication & Authorization
==============================

JWT-based authentication with API key support.
"""

from .jwt_auth import (
    JWTAuth,
    TokenPayload,
    create_access_token,
    create_refresh_token,
    verify_token,
    get_current_user,
    require_auth,
    require_role,
)

from .api_keys import (
    APIKeyAuth,
    generate_api_key,
    hash_api_key,
    verify_api_key,
)

from .password import (
    hash_password,
    verify_password,
    check_password_strength,
)

__all__ = [
    # JWT
    "JWTAuth",
    "TokenPayload",
    "create_access_token",
    "create_refresh_token",
    "verify_token",
    "get_current_user",
    "require_auth",
    "require_role",
    # API Keys
    "APIKeyAuth",
    "generate_api_key",
    "hash_api_key",
    "verify_api_key",
    # Password
    "hash_password",
    "verify_password",
    "check_password_strength",
]
