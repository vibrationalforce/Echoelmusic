"""
Password Utilities
==================

Secure password hashing and validation.
"""

import re
from typing import Tuple, List
from passlib.context import CryptContext

# Password hashing context
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=12  # Increase for more security (slower)
)


def hash_password(password: str) -> str:
    """
    Hash a password using bcrypt.

    Args:
        password: Plain text password

    Returns:
        Hashed password string
    """
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Verify a password against its hash.

    Args:
        plain_password: Plain text password to verify
        hashed_password: Stored hash to verify against

    Returns:
        True if password matches, False otherwise
    """
    return pwd_context.verify(plain_password, hashed_password)


def check_password_strength(password: str) -> Tuple[bool, List[str]]:
    """
    Check password strength against security requirements.

    Requirements:
    - Minimum 8 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character

    Args:
        password: Password to check

    Returns:
        Tuple of (is_valid, list of issues)
    """
    issues = []

    if len(password) < 8:
        issues.append("Password must be at least 8 characters long")

    if len(password) > 128:
        issues.append("Password must be at most 128 characters long")

    if not re.search(r"[A-Z]", password):
        issues.append("Password must contain at least one uppercase letter")

    if not re.search(r"[a-z]", password):
        issues.append("Password must contain at least one lowercase letter")

    if not re.search(r"\d", password):
        issues.append("Password must contain at least one digit")

    if not re.search(r"[!@#$%^&*(),.?\":{}|<>]", password):
        issues.append("Password must contain at least one special character")

    # Check for common patterns
    common_patterns = [
        r"^password",
        r"^123456",
        r"^qwerty",
        r"(.)\1{3,}",  # Same character repeated 4+ times
    ]

    for pattern in common_patterns:
        if re.search(pattern, password, re.IGNORECASE):
            issues.append("Password contains a common pattern")
            break

    return len(issues) == 0, issues


def needs_rehash(hashed_password: str) -> bool:
    """
    Check if a password hash needs to be rehashed.

    This happens when the hashing algorithm or parameters change.

    Args:
        hashed_password: Current password hash

    Returns:
        True if password should be rehashed
    """
    return pwd_context.needs_update(hashed_password)
