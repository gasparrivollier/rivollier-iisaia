import pytest
from sqlalchemy import create_engine, text

from app.routers.identify import get_plantnet_client, get_storage
from app.services.plantnet_client import PlantnetUnavailable
from tests.fakes import FakePlantnet, FakeStorage
from tests.images import png_bytes

pytestmark = pytest.mark.integration

PW = "correct-horse-42"


def _token(api, email="ident@example.com") -> str:
    res = api.post("/auth/register", json={"email": email, "password": PW, "display_name": "Ident"})
    return res.json()["access_token"]


def _counts(url) -> dict[str, int]:
    engine = create_engine(url)
    with engine.connect() as conn:
        out = {
            t: conn.execute(text(f"SELECT count(*) FROM {t}")).scalar_one()
            for t in ("identifications", "identification_images", "identification_results")
        }
    engine.dispose()
    return out


@pytest.fixture
def fakes(api):
    plantnet, storage = FakePlantnet(), FakeStorage()
    api.app.dependency_overrides[get_plantnet_client] = lambda: plantnet
    api.app.dependency_overrides[get_storage] = lambda: storage
    return plantnet, storage


def _identify(api, token, data=None):
    return api.post(
        "/identify",
        files={"image": ("p.png", data or png_bytes(), "image/png")},
        headers={"Authorization": f"Bearer {token}"},
    )


def test_identify_writes_all_three_tables(api, migrated_url, fakes):
    res = _identify(api, _token(api))
    assert res.status_code == 200
    assert _counts(migrated_url) == {
        "identifications": 1,
        "identification_images": 1,
        "identification_results": 10,
    }
    engine = create_engine(migrated_url)
    with engine.connect() as conn:
        row = conn.execute(
            text(
                "SELECT project, plantnet_version, remaining_requests_at_call, best_match "
                "FROM identifications"
            )
        ).one()
        names = conn.execute(
            text("SELECT common_names FROM identification_results WHERE rank = 1")
        ).scalar_one()
    engine.dispose()
    assert tuple(row) == ("all", "2026-03-20 (7.5)", 497, "Murraya paniculata (L.) Jack")
    assert names == ["Orange Jasmine", "Orange jessamine", "Mock orange"]  # real jsonb list


def test_failed_identify_writes_no_rows(api, migrated_url, fakes):
    plantnet, _ = fakes
    plantnet.error = PlantnetUnavailable("x")
    assert _identify(api, _token(api)).status_code == 502
    assert _counts(migrated_url) == {
        "identifications": 0,
        "identification_images": 0,
        "identification_results": 0,
    }


def test_invalid_image_writes_no_rows(api, migrated_url, fakes):
    assert _identify(api, _token(api), data=png_bytes(100, 100)).status_code == 422
    assert _counts(migrated_url)["identifications"] == 0


def test_user_deletion_cascades_to_identifications(api, migrated_url, fakes):
    _identify(api, _token(api))
    engine = create_engine(migrated_url)
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM users"))
    engine.dispose()
    assert _counts(migrated_url)["identification_results"] == 0
