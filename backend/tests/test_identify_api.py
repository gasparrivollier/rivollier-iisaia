import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.core.deps import get_current_user
from app.db import get_db
from app.models import Identification, User
from app.routers.identify import get_plantnet_client, get_storage
from app.services.plantnet_client import (
    PlantnetNoPlant,
    PlantnetRateLimited,
    PlantnetUnavailable,
)
from app.services.storage import StorageError
from tests.fakes import FakePlantnet, FakeStorage, RecordingSession
from tests.images import jpeg_bytes, png_bytes

ALICE = User(id=1, email="alice@example.com", password_hash="x", display_name="Alice")
APP_ORIGIN = "http://127.0.0.1:8080"


@pytest.fixture
def env(app):
    """App with fake Pl@ntNet, storage and DB; signed in as ALICE."""
    state = type("Env", (), {})()
    state.plantnet, state.storage, state.db = FakePlantnet(), FakeStorage(), RecordingSession()
    app.dependency_overrides[get_current_user] = lambda: ALICE
    app.dependency_overrides[get_plantnet_client] = lambda: state.plantnet
    app.dependency_overrides[get_storage] = lambda: state.storage
    app.dependency_overrides[get_db] = lambda: state.db
    state.client = TestClient(app)
    yield state
    app.dependency_overrides.clear()


def _post(client, data: bytes, name="photo.png", mime="image/png", **kw):
    return client.post("/identify", files={"image": (name, data, mime)}, **kw)


def test_happy_path_returns_ranked_results_and_persists(env):
    data = png_bytes()
    res = _post(env.client, data)
    assert res.status_code == 200
    body = res.json()
    assert body["identification_id"] == 7
    assert body["project"] == "all"
    assert body["best_match"] == "Murraya paniculata (L.) Jack"
    assert body["remaining_requests"] == 497
    assert len(body["results"]) == 10
    assert body["results"][0]["rank"] == 1
    assert body["results"][0]["scientific_name_without_author"] == "Murraya paniculata"
    assert body["image"]["predicted_organ"] == "flower"

    [call] = env.plantnet.calls
    assert call["organ"] == "auto" and call["project"] == "all"
    assert call["content"] == data and call["filename"] == "photo.png"

    [(key, (stored, ctype))] = env.storage.objects.items()
    assert key.startswith("identifications/1/") and key.endswith(".png")
    assert (stored, ctype) == (data, "image/png")
    assert body["image"]["url"] == f"http://files.test/{key}?sig=1"

    [ident] = env.db.added
    assert isinstance(ident, Identification) and env.db.commits == 1
    assert ident.images[0].storage_key == key


def test_jpeg_keeps_its_extension_and_the_users_file_name_is_not_forwarded(env):
    res = _post(env.client, jpeg_bytes(), name="my-secret-name.jpeg", mime="image/jpeg")
    assert res.status_code == 200
    assert env.plantnet.calls[0]["filename"] == "photo.jpg"
    assert next(iter(env.storage.objects)).endswith(".jpg")
    assert "my-secret-name" not in next(iter(env.storage.objects))


def test_requires_authentication(app):
    plantnet = FakePlantnet()
    app.dependency_overrides[get_plantnet_client] = lambda: plantnet
    app.dependency_overrides[get_storage] = lambda: FakeStorage()
    app.dependency_overrides[get_db] = lambda: RecordingSession()
    res = _post(TestClient(app), png_bytes())  # no bearer header, real get_current_user
    app.dependency_overrides.clear()
    assert res.status_code == 401
    assert res.headers["www-authenticate"] == "Bearer"
    assert plantnet.calls == []


@pytest.mark.parametrize(
    ("data", "status"),
    [
        (b"GIF89a" + b"\x00" * 100, 422),
        (png_bytes(799, 800), 422),
        (png_bytes()[:200], 422),
        (b"", 422),
        (b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024), 413),
    ],
    ids=["gif", "undersized", "truncated", "empty", "too-large"],
)
def test_rejected_images_touch_nothing(env, data, status):
    res = _post(env.client, data)
    assert res.status_code == status
    assert isinstance(res.json()["detail"], str)
    assert env.plantnet.calls == []
    assert env.storage.objects == {}
    assert env.db.added == [] and env.db.commits == 0


def test_missing_image_field_is_422_on_the_image_field(env):
    res = env.client.post("/identify", data={"other": "x"})
    assert res.status_code == 422
    assert res.json()["detail"][0]["loc"][-1] == "image"
    assert env.plantnet.calls == []


def test_plantnet_429_passes_retry_after_through_and_exposes_it_to_browsers(env):
    env.plantnet.error = PlantnetRateLimited("Wed, 15 Oct 2026 00:00:00 GMT")
    res = _post(env.client, png_bytes(), headers={"Origin": APP_ORIGIN})
    assert res.status_code == 429
    assert res.headers["retry-after"] == "Wed, 15 Oct 2026 00:00:00 GMT"
    assert "retry-after" in res.headers["access-control-expose-headers"].lower()
    assert env.storage.objects == {} and env.db.added == []


def test_plantnet_no_plant_is_422(env):
    env.plantnet.error = PlantnetNoPlant("x")
    res = _post(env.client, png_bytes())
    assert res.status_code == 422
    assert "plant" in res.json()["detail"].lower()
    assert env.storage.objects == {} and env.db.added == []


def test_plantnet_unavailable_is_502(env):
    env.plantnet.error = PlantnetUnavailable("x")
    res = _post(env.client, png_bytes())
    assert res.status_code == 502
    assert env.storage.objects == {} and env.db.added == []


def test_storage_failure_is_502_and_commits_nothing(env):
    env.storage.error = StorageError("x")
    res = _post(env.client, png_bytes())
    assert res.status_code == 502
    assert env.db.added == [] and env.db.commits == 0


def test_db_failure_is_a_503_with_cors_headers_so_the_browser_can_read_it(env):
    env.db.fail_on_commit = OperationalError("INSERT", {}, Exception("db down"))
    res = _post(env.client, png_bytes(), headers={"Origin": APP_ORIGIN})
    assert res.status_code == 503
    assert res.headers["access-control-allow-origin"] == APP_ORIGIN
    assert env.db.rollbacks == 1
