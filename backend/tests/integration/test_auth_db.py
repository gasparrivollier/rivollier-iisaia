import pytest
from sqlalchemy import create_engine, text

pytestmark = pytest.mark.integration

PW = "correct-horse-42"


def _register(api, email="Ana@Example.com", password=PW, name="Ana"):
    return api.post(
        "/auth/register", json={"email": email, "password": password, "display_name": name}
    )


def _me(api, token):
    return api.get("/auth/me", headers={"Authorization": f"Bearer {token}"})


def test_register_returns_token_and_normalized_user(api, migrated_url):
    res = _register(api)
    assert res.status_code == 201
    body = res.json()
    assert body["token_type"] == "bearer"
    assert body["user"]["email"] == "ana@example.com"
    assert body["user"]["display_name"] == "Ana"
    engine = create_engine(migrated_url)
    with engine.connect() as conn:
        stored = conn.execute(text("SELECT password_hash FROM users")).scalar_one()
    engine.dispose()
    assert stored.startswith("$2") and PW not in stored


def test_register_token_works_on_me(api):
    body = _register(api).json()
    res = _me(api, body["access_token"])
    assert res.status_code == 200
    assert res.json() == body["user"]


def test_duplicate_email_in_other_case_is_409(api):
    assert _register(api).status_code == 201
    res = _register(api, email="  ANA@example.com ")
    assert res.status_code == 409
    assert res.json() == {"detail": "Email already registered"}


def test_login_is_case_insensitive_and_token_works(api):
    _register(api)
    res = api.post("/auth/login", json={"email": "ana@EXAMPLE.com", "password": PW})
    assert res.status_code == 200
    assert _me(api, res.json()["access_token"]).json()["email"] == "ana@example.com"


def test_wrong_password_and_unknown_email_look_identical(api):
    _register(api)
    wrong = api.post("/auth/login", json={"email": "ana@example.com", "password": "nope-nope"})
    unknown = api.post("/auth/login", json={"email": "bob@example.com", "password": PW})
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json() == {"detail": "Invalid email or password"}


def test_login_with_overlong_password_is_401(api):
    _register(api)
    res = api.post("/auth/login", json={"email": "ana@example.com", "password": "é" * 40})
    assert res.status_code == 401


def test_token_of_deleted_user_is_rejected(api, migrated_url):
    token = _register(api).json()["access_token"]
    engine = create_engine(migrated_url)
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM users"))
    engine.dispose()
    res = _me(api, token)
    assert res.status_code == 401
    assert res.headers["www-authenticate"] == "Bearer"
