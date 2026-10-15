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


def _raw(client, blobs, organs, mime="image/png", **kw):
    """Posts `blobs` as repeated `images` parts and `organs` as repeated form fields."""
    files = [("images", (f"upload{i}.png", data, mime)) for i, data in enumerate(blobs)]
    return client.post("/identify", files=files, data={"organs": organs}, **kw)


def _one(client, data=None, organ="auto", **kw):
    return _raw(client, [data or png_bytes()], [organ], **kw)


def _assert_untouched(env):
    assert env.plantnet.calls == []
    assert env.storage.objects == {}
    assert env.db.added == [] and env.db.commits == 0


def test_single_photo_happy_path(env):
    data = png_bytes()
    res = _one(env.client, data, "flower")
    assert res.status_code == 200
    body = res.json()
    assert body["identification_id"] == 7
    assert body["project"] == "all"
    assert body["best_match"] == "Murraya paniculata (L.) Jack"
    assert body["remaining_requests"] == 497
    assert len(body["results"]) == 10
    assert body["results"][0]["scientific_name_without_author"] == "Murraya paniculata"

    [call] = env.plantnet.calls
    assert call["project"] == "all"
    [part] = call["images"]
    assert (part.filename, part.content, part.organ) == ("photo1.png", data, "flower")

    [(key, (stored, ctype))] = env.storage.objects.items()
    assert key.startswith("identifications/1/") and key.endswith(".png")
    assert (stored, ctype) == (data, "image/png")
    [img] = body["images"]
    assert img == {
        "url": f"http://files.test/{key}?sig=1",
        "organ": "flower",
        "predicted_organ": "flower",
        "predicted_organ_score": 0.77573,
        "sort_order": 0,
    }


def test_three_photos_are_forwarded_in_order_with_their_organs(env):
    blobs = [png_bytes(800, 800), jpeg_bytes(900, 900), png_bytes(1000, 1000)]
    res = _raw(env.client, blobs, ["flower", "leaf", "auto"])
    assert res.status_code == 200
    body = res.json()

    [call] = env.plantnet.calls
    assert [p.organ for p in call["images"]] == ["flower", "leaf", "auto"]
    assert [p.content for p in call["images"]] == blobs
    # The user's file names are never forwarded; the extension comes from the sniffed type.
    assert [p.filename for p in call["images"]] == ["photo1.png", "photo2.jpg", "photo3.png"]

    keys = list(env.storage.objects)
    assert [k.rsplit(".", 1)[1] for k in keys] == ["png", "jpg", "png"]
    assert all(k.startswith("identifications/1/") for k in keys)
    assert "upload" not in "".join(keys)

    [ident] = env.db.added
    assert isinstance(ident, Identification) and env.db.commits == 1
    assert [(i.storage_key, i.organ, i.sort_order) for i in ident.images] == [
        (keys[0], "flower", 0),
        (keys[1], "leaf", 1),
        (keys[2], "auto", 2),
    ]

    assert [i["sort_order"] for i in body["images"]] == [0, 1, 2]
    assert [i["organ"] for i in body["images"]] == ["flower", "leaf", "auto"]
    assert [i["predicted_organ"] for i in body["images"]] == ["flower", "habit", "flower"]
    assert [i["url"] for i in body["images"]] == [f"http://files.test/{k}?sig=1" for k in keys]


def test_requires_authentication(app):
    plantnet = FakePlantnet()
    app.dependency_overrides[get_plantnet_client] = lambda: plantnet
    app.dependency_overrides[get_storage] = lambda: FakeStorage()
    app.dependency_overrides[get_db] = lambda: RecordingSession()
    res = _one(TestClient(app))  # no bearer header, real get_current_user
    app.dependency_overrides.clear()
    assert res.status_code == 401
    assert res.headers["www-authenticate"] == "Bearer"
    assert plantnet.calls == []


GOOD = png_bytes()
OVER_TEN_MIB = b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024)
NEAR_CAP = b"\x89PNG\r\n\x1a\n" + b"0" * (50_000_000 // 5 + 1)


@pytest.mark.parametrize(
    ("blobs", "organs", "status", "fragment"),
    [
        ([GOOD] * 6, ["auto"] * 6, 422, "At most"),
        ([GOOD, GOOD], ["auto"], 422, "organ"),
        ([GOOD], ["auto", "leaf"], 422, "organ"),
        ([GOOD, GOOD], ["auto", "petal"], 422, "Photo 2"),
        ([GOOD, b"GIF89a" + b"\x00" * 100, GOOD], ["auto"] * 3, 422, "Photo 2"),
        ([GOOD, png_bytes(799, 800)], ["auto"] * 2, 422, "Photo 2"),
        ([GOOD, b""], ["auto"] * 2, 422, "Photo 2"),
        ([GOOD, OVER_TEN_MIB], ["auto"] * 2, 413, "Photo 2"),
        ([NEAR_CAP] * 5, ["auto"] * 5, 413, "50 MB"),
    ],
    ids=[
        "six-photos",
        "fewer-organs-than-photos",
        "more-organs-than-photos",
        "unknown-organ",
        "gif-among-good",
        "undersized-among-good",
        "empty-among-good",
        "one-over-10MiB",
        "set-over-50MB",
    ],
)
def test_rejected_sets_touch_nothing(env, blobs, organs, status, fragment):
    res = _raw(env.client, blobs, organs)
    assert res.status_code == status
    assert fragment in res.json()["detail"]
    _assert_untouched(env)


@pytest.mark.parametrize("field", ["images", "organs"])
def test_missing_field_is_422_on_that_field(env, field):
    if field == "images":
        res = env.client.post("/identify", data={"organs": ["auto"]})
    else:
        res = env.client.post("/identify", files=[("images", ("a.png", GOOD, "image/png"))])
    assert res.status_code == 422
    assert res.json()["detail"][0]["loc"][-1] == field
    _assert_untouched(env)


def test_plantnet_429_passes_retry_after_through_and_exposes_it_to_browsers(env):
    env.plantnet.error = PlantnetRateLimited("Wed, 15 Oct 2026 00:00:00 GMT")
    res = _one(env.client, headers={"Origin": APP_ORIGIN})
    assert res.status_code == 429
    assert res.headers["retry-after"] == "Wed, 15 Oct 2026 00:00:00 GMT"
    assert "retry-after" in res.headers["access-control-expose-headers"].lower()
    assert env.storage.objects == {} and env.db.added == []


def test_plantnet_no_plant_is_422(env):
    env.plantnet.error = PlantnetNoPlant("x")
    res = _one(env.client)
    assert res.status_code == 422
    assert "plant" in res.json()["detail"].lower()
    assert env.storage.objects == {} and env.db.added == []


def test_plantnet_unavailable_is_502(env):
    env.plantnet.error = PlantnetUnavailable("x")
    res = _one(env.client)
    assert res.status_code == 502
    assert env.storage.objects == {} and env.db.added == []


def test_storage_failure_is_502_and_commits_nothing(env):
    env.storage.error = StorageError("x")
    res = _one(env.client)
    assert res.status_code == 502
    assert env.db.added == [] and env.db.commits == 0


def test_second_upload_failing_is_502_and_commits_nothing(env):
    env.storage.error = StorageError("x")
    env.storage.fail_after = 1  # first put succeeds, second fails
    res = _raw(env.client, [png_bytes(), png_bytes(), png_bytes()], ["auto"] * 3)
    assert res.status_code == 502
    assert len(env.storage.objects) == 1  # the orphan the plan accepts
    assert env.db.added == [] and env.db.commits == 0


def test_db_failure_is_a_503_with_cors_headers_so_the_browser_can_read_it(env):
    env.db.fail_on_commit = OperationalError("INSERT", {}, Exception("db down"))
    res = _one(env.client, headers={"Origin": APP_ORIGIN})
    assert res.status_code == 503
    assert res.headers["access-control-allow-origin"] == APP_ORIGIN
    assert env.db.rollbacks == 1
