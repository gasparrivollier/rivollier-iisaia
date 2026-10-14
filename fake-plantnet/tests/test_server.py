from datetime import UTC, datetime
from email.utils import parsedate_to_datetime

import pytest
from fastapi.testclient import TestClient

from server import create_app

IMG = {"images": ("leaf.jpg", b"\xff\xd8fake", "image/jpeg")}


@pytest.fixture
def client():
    with TestClient(create_app()) as c:
        yield c


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_identify_replays_recorded_response(client):
    res = client.post("/v2/identify/all?api-key=k", files=IMG, data={"organs": "auto"})
    assert res.status_code == 200
    body = res.json()
    assert body["bestMatch"] == "Murraya paniculata (L.) Jack"
    assert len(body["results"]) == 10
    assert body["query"]["project"] == "all"
    assert "RateLimit" in res.headers and "RateLimit-Policy" in res.headers


def test_identify_echoes_project(client):
    res = client.post("/v2/identify/k-world-flora?api-key=k", files=IMG, data={"organs": "auto"})
    assert res.json()["query"]["project"] == "k-world-flora"


def test_missing_api_key_is_401(client):
    assert client.post("/v2/identify/all", files=IMG).status_code == 401


def test_no_images_is_400(client):
    res = client.post("/v2/identify/all?api-key=k", data={"organs": "auto"})
    assert res.status_code == 400


def test_forced_429_applies_once_with_retry_after(client):
    assert client.post("/_control/next-status", json={"status": 429}).status_code == 200
    first = client.post("/v2/identify/all?api-key=k", files=IMG)
    assert first.status_code == 429
    retry_at = parsedate_to_datetime(first.headers["Retry-After"])
    assert retry_at > datetime.now(UTC)
    second = client.post("/v2/identify/all?api-key=k", files=IMG)
    assert second.status_code == 200
