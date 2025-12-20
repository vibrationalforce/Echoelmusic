"""
JWT Authentication
==================

Secure token-based authentication for API access.
"""

import os
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from functools import wraps

from fastapi import HTTPException, Depends, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from pydantic import BaseModel

# Configuration
JWT_SECRET = os.environ.get("JWT_SECRET", "CHANGE_THIS_IN_PRODUCTION")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7


class TokenPayload(BaseModel):
    """JWT token payload."""
    sub: str  # User ID
    email: Optional[str] = None
    role: str = "user"
    exp: datetime
    iat: datetime
    type: str = "access"  # access or refresh


class JWTAuth(HTTPBearer):
    """JWT authentication handler."""

    def __init__(self, auto_error: bool = True):
        super().__init__(auto_error=auto_error)

    async def __call__(self, request: Request) -> Optional[TokenPayload]:
        credentials: HTTPAuthorizationCredentials = await super().__call__(request)

        if not credentials:
            if self.auto_error:
                raise HTTPException(status_code=401, detail="Not authenticated")
            return None

        if credentials.scheme.lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid authentication scheme")

        token = credentials.credentials
        payload = verify_token(token)

        if not payload:
            raise HTTPException(status_code=401, detail="Invalid or expired token")

        return payload


def create_access_token(
    user_id: str,
    email: str = None,
    role: str = "user",
    expires_delta: timedelta = None
) -> str:
    """Create a new access token."""
    if expires_delta is None:
        expires_delta = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    now = datetime.utcnow()
    expire = now + expires_delta

    payload = {
        "sub": user_id,
        "email": email,
        "role": role,
        "exp": expire,
        "iat": now,
        "type": "access"
    }

    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    """Create a new refresh token."""
    now = datetime.utcnow()
    expire = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)

    payload = {
        "sub": user_id,
        "exp": expire,
        "iat": now,
        "type": "refresh"
    }

    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def verify_token(token: str) -> Optional[TokenPayload]:
    """Verify and decode a JWT token."""
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        return TokenPayload(**payload)
    except JWTError:
        return None


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(HTTPBearer())
) -> TokenPayload:
    """Get current authenticated user from token."""
    token = credentials.credentials
    payload = verify_token(token)

    if not payload:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"}
        )

    if payload.type != "access":
        raise HTTPException(
            status_code=401,
            detail="Invalid token type"
        )

    return payload


def require_auth(func):
    """Decorator to require authentication."""
    @wraps(func)
    async def wrapper(*args, **kwargs):
        request = kwargs.get("request")
        if not request:
            for arg in args:
                if isinstance(arg, Request):
                    request = arg
                    break

        if not request:
            raise HTTPException(status_code=500, detail="Request not found")

        auth = JWTAuth()
        payload = await auth(request)

        if not payload:
            raise HTTPException(status_code=401, detail="Not authenticated")

        kwargs["current_user"] = payload
        return await func(*args, **kwargs)

    return wrapper


def require_role(*allowed_roles: str):
    """Decorator to require specific roles."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, current_user: TokenPayload = None, **kwargs):
            if not current_user:
                raise HTTPException(status_code=401, detail="Not authenticated")

            if current_user.role not in allowed_roles:
                raise HTTPException(
                    status_code=403,
                    detail=f"Role '{current_user.role}' not allowed. Required: {allowed_roles}"
                )

            return await func(*args, current_user=current_user, **kwargs)
        return wrapper
    return decorator


class AuthService:
    """Authentication service for user management."""

    async def login(self, email: str, password: str) -> Dict[str, str]:
        """Authenticate user and return tokens."""
        # In production, verify against database
        from .password import verify_password

        # Mock user lookup - replace with DB query
        user = await self._get_user_by_email(email)
        if not user:
            raise HTTPException(status_code=401, detail="Invalid credentials")

        if not verify_password(password, user["password_hash"]):
            raise HTTPException(status_code=401, detail="Invalid credentials")

        access_token = create_access_token(
            user_id=user["id"],
            email=user["email"],
            role=user["role"]
        )
        refresh_token = create_refresh_token(user["id"])

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer"
        }

    async def refresh(self, refresh_token: str) -> Dict[str, str]:
        """Refresh access token using refresh token."""
        payload = verify_token(refresh_token)

        if not payload or payload.type != "refresh":
            raise HTTPException(status_code=401, detail="Invalid refresh token")

        user = await self._get_user_by_id(payload.sub)
        if not user:
            raise HTTPException(status_code=401, detail="User not found")

        access_token = create_access_token(
            user_id=user["id"],
            email=user["email"],
            role=user["role"]
        )

        return {
            "access_token": access_token,
            "token_type": "bearer"
        }

    async def _get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email - implement with actual DB."""
        # Placeholder - replace with database query
        return None

    async def _get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID - implement with actual DB."""
        # Placeholder - replace with database query
        return None


# Global auth service instance
auth_service = AuthService()
