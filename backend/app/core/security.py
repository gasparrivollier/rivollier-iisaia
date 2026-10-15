"""Password hashing (bcrypt) and access-token issue/verify (HS256 JWT)."""

from datetime import UTC, datetime, timedelta

import bcrypt
import jwt

ALGORITHM = "HS256"
# bcrypt only reads the first 72 bytes, and bcrypt>=5 raises on longer input.
MAX_PASSWORD_BYTES = 72


class InvalidTokenError(Exception):
    """The bearer token is malformed, forged, expired or missing required claims."""


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, password_hash: str) -> bool:
    raw = password.encode()
    if len(raw) > MAX_PASSWORD_BYTES:
        return False
    return bcrypt.checkpw(raw, password_hash.encode())


def create_access_token(
    user_id: int, *, secret: str, ttl_minutes: int, now: datetime | None = None
) -> str:
    issued = now or datetime.now(UTC)
    payload = {"sub": str(user_id), "iat": issued, "exp": issued + timedelta(minutes=ttl_minutes)}
    return jwt.encode(payload, secret, algorithm=ALGORITHM)


def decode_access_token(token: str, *, secret: str) -> int:
    try:
        payload = jwt.decode(
            token, secret, algorithms=[ALGORITHM], options={"require": ["exp", "sub"]}
        )
        return int(payload["sub"])
    except (jwt.PyJWTError, ValueError, TypeError) as exc:
        raise InvalidTokenError(str(exc)) from exc
