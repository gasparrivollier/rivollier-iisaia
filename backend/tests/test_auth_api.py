from datetime import UTC, datetime, timedelta

import jwt
import pytest
from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.db import get_db
from app.models import User
from app.schemas.auth import RegisterRequest

SECRET = "test-secret-0123456789abcdef0123456789"  # matches conftest's JWT_SECRET
APP_ORIGIN = "http://127.0.0.1:8080"


class _UserSession:
    """Stand-in Session whose .get() returns a fixed user (or None = deleted user)."""

    def __init__(self, user: User | None):
        self._user = user

    def get(self, _model, _id):
        return self._user


@pytest.fixture
def client_with_user(app):
    def _make(user: User | None) -> TestClient:
        def _db():
            yield _UserSession(user)

        app.dependency_overrides[get_db] = _db
        return TestClient(app)

    yield _make
    app.dependency_overrides.clear()


ALICE = User(id=1, email="alice@example.com", password_hash="x", display_name="Alice")


def _bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _assert_401(res):
    assert res.status_code == 401
    assert res.headers["www-authenticate"] == "Bearer"
    assert res.json() == {"detail": "Not authenticated"}


def test_me_returns_user_for_valid_token(client_with_user):
    token = create_access_token(1, secret=SECRET, ttl_minutes=5)
    res = client_with_user(ALICE).get("/auth/me", headers=_bearer(token))
    assert res.status_code == 200
    assert res.json() == {"id": 1, "email": "alice@example.com", "display_name": "Alice"}


def _future() -> datetime:
    return datetime.now(UTC) + timedelta(minutes=5)


@pytest.mark.parametrize(
    "headers",
    [
        pytest.param({}, id="missing-header"),
        pytest.param({"Authorization": "Basic YTpi"}, id="wrong-scheme"),
        pytest.param(_bearer("not-a-jwt"), id="garbage"),
        pytest.param(
            _bearer(
                create_access_token(1, secret="other-secret-0123456789abcdef0123", ttl_minutes=5)
            ),
            id="wrong-secret",
        ),
        pytest.param(
            _bearer(
                create_access_token(
                    1, secret=SECRET, ttl_minutes=1, now=datetime.now(UTC) - timedelta(hours=1)
                )
            ),
            id="expired",
        ),
        pytest.param(
            _bearer(jwt.encode({"sub": "1", "exp": _future()}, None, algorithm="none")),
            id="alg-none",
        ),
        pytest.param(
            _bearer(jwt.encode({"exp": _future()}, SECRET, algorithm="HS256")), id="missing-sub"
        ),
    ],
)
def test_me_rejects_bad_credentials(client_with_user, headers):
    _assert_401(client_with_user(ALICE).get("/auth/me", headers=headers))


def test_me_rejects_token_of_deleted_user(client_with_user):
    token = create_access_token(1, secret=SECRET, ttl_minutes=5)
    _assert_401(client_with_user(None).get("/auth/me", headers=_bearer(token)))


@pytest.mark.parametrize(
    "body",
    [
        pytest.param(
            {"email": "a@example.com", "password": "short", "display_name": "A"},
            id="password-too-short",
        ),
        pytest.param(
            {"email": "a@example.com", "password": "é" * 40, "display_name": "A"},
            id="password-over-72-bytes",
        ),
        pytest.param(
            {"email": "not-an-email", "password": "long-enough", "display_name": "A"},
            id="bad-email",
        ),
        pytest.param(
            {"email": "a@example.com", "password": "long-enough", "display_name": "   "},
            id="blank-display-name",
        ),
        pytest.param({"email": "a@example.com", "password": "long-enough"}, id="missing-name"),
    ],
)
def test_register_validation_is_422(client_with_db, body):
    assert client_with_db.post("/auth/register", json=body).status_code == 422


def test_register_rejects_password_over_72_bytes():
    # Explicit Review Focus #1 pin (also covered by the parametrized case above).
    with pytest.raises(ValueError):
        RegisterRequest(email="a@example.com", password="é" * 40, display_name="A")


def test_register_request_normalizes_and_accepts_e2e_emails():
    req = RegisterRequest(
        email="  E2E-ui-1728000000-42@Example.COM ", password="long-enough", display_name=" Pat "
    )
    assert req.email == "e2e-ui-1728000000-42@example.com"
    assert req.display_name == "Pat"


def test_cors_preflight_allows_app_origin_with_authorization(client_with_db):
    res = client_with_db.options(
        "/auth/me",
        headers={
            "Origin": APP_ORIGIN,
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization",
        },
    )
    assert res.status_code == 200
    assert res.headers["access-control-allow-origin"] == APP_ORIGIN
    assert "authorization" in res.headers["access-control-allow-headers"].lower()


def test_cors_does_not_allow_unknown_origin(client_with_db):
    res = client_with_db.options(
        "/auth/me",
        headers={"Origin": "http://evil.example", "Access-Control-Request-Method": "GET"},
    )
    assert "access-control-allow-origin" not in res.headers
