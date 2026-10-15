from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.security import (
    InvalidTokenError,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)

SECRET = "test-secret-0123456789abcdef0123456789"


def test_hash_roundtrip_and_not_plaintext():
    h = hash_password("correct-horse-42")
    assert h != "correct-horse-42" and h.startswith("$2")
    assert verify_password("correct-horse-42", h)
    assert not verify_password("wrong-horse-42", h)


def test_verify_password_rejects_over_72_bytes():
    h = hash_password("correct-horse-42")
    assert verify_password("é" * 40, h) is False  # 80 bytes: must not raise


def test_token_roundtrip_returns_user_id():
    token = create_access_token(42, secret=SECRET, ttl_minutes=5)
    assert decode_access_token(token, secret=SECRET) == 42


def test_expired_token_is_rejected():
    past = datetime.now(UTC) - timedelta(minutes=10)
    token = create_access_token(1, secret=SECRET, ttl_minutes=1, now=past)
    with pytest.raises(InvalidTokenError):
        decode_access_token(token, secret=SECRET)


def test_wrong_secret_is_rejected():
    token = create_access_token(1, secret=SECRET, ttl_minutes=5)
    with pytest.raises(InvalidTokenError):
        decode_access_token(token, secret="another-secret-0123456789abcdef0123")


def _future() -> datetime:
    return datetime.now(UTC) + timedelta(minutes=5)


@pytest.mark.parametrize(
    "token_factory",
    [
        pytest.param(
            lambda: jwt.encode({"sub": "1", "exp": _future()}, None, algorithm="none"),
            id="alg-none",
        ),
        pytest.param(
            lambda: jwt.encode({"exp": _future()}, SECRET, algorithm="HS256"), id="missing-sub"
        ),
        pytest.param(
            lambda: jwt.encode({"sub": "abc", "exp": _future()}, SECRET, algorithm="HS256"),
            id="non-integer-sub",
        ),
        pytest.param(lambda: jwt.encode({"sub": "1"}, SECRET, algorithm="HS256"), id="missing-exp"),
        pytest.param(lambda: "not-a-jwt", id="garbage"),
    ],
)
def test_malformed_tokens_are_rejected(token_factory):
    with pytest.raises(InvalidTokenError):
        decode_access_token(token_factory(), secret=SECRET)
