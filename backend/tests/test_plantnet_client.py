import json
from pathlib import Path

import httpx
import pytest
import respx

from app.services.plantnet_client import (
    PlantnetClient,
    PlantnetNoPlant,
    PlantnetRateLimited,
    PlantnetUnavailable,
)

RECORDED = json.loads(
    (
        Path(__file__).resolve().parents[2] / "docs/examples/plantnet-identify-response.json"
    ).read_text()
)
BASE = "http://plantnet.test"
KEY = "super-secret-key"
URL = f"{BASE}/v2/identify/all"


def _client() -> PlantnetClient:
    return PlantnetClient(BASE, KEY, timeout=2.0)


def _identify(client: PlantnetClient | None = None):
    return (client or _client()).identify(
        project="all", filename="photo.png", content=b"PNGDATA", content_type="image/png"
    )


@respx.mock
def test_identify_posts_multipart_with_api_key_and_parses_the_response():
    route = respx.post(URL).mock(return_value=httpx.Response(200, json=RECORDED))
    result = _identify()

    req = route.calls.last.request
    assert req.url.params["api-key"] == KEY
    body = req.content
    assert b'name="images"; filename="photo.png"' in body
    assert b"PNGDATA" in body
    assert b'name="organs"' in body and b"auto" in body

    assert len(result.results) == 10
    top = result.results[0]
    assert top.species.scientificNameWithoutAuthor == "Murraya paniculata"
    assert top.species.scientificName == "Murraya paniculata (L.) Jack"
    assert top.species.family.scientificNameWithoutAuthor == "Rutaceae"
    assert top.gbif.id == "5421335"
    assert result.version == "2026-03-20 (7.5)"
    assert result.remainingIdentificationRequests == 497
    assert result.predictedOrgans[0].organ == "flower"


@respx.mock
def test_429_raises_rate_limited_with_retry_after():
    respx.post(URL).mock(
        return_value=httpx.Response(429, headers={"Retry-After": "Wed, 15 Oct 2026 00:00:00 GMT"})
    )
    with pytest.raises(PlantnetRateLimited) as exc:
        _identify()
    assert exc.value.retry_after == "Wed, 15 Oct 2026 00:00:00 GMT"


@respx.mock
def test_404_means_no_plant_detected():
    respx.post(URL).mock(return_value=httpx.Response(404, json={"message": "Species not found"}))
    with pytest.raises(PlantnetNoPlant):
        _identify()


@respx.mock
@pytest.mark.parametrize("status", [400, 401, 500, 503])
def test_other_statuses_are_unavailable(status):
    respx.post(URL).mock(return_value=httpx.Response(status, json={"message": "boom"}))
    with pytest.raises(PlantnetUnavailable):
        _identify()


@respx.mock
def test_unparseable_success_body_is_unavailable():
    respx.post(URL).mock(return_value=httpx.Response(200, text="<html>proxy page</html>"))
    with pytest.raises(PlantnetUnavailable):
        _identify()
    respx.post(URL).mock(return_value=httpx.Response(200, json={"unexpected": True}))
    with pytest.raises(PlantnetUnavailable):
        _identify()


@respx.mock
@pytest.mark.parametrize("exc", [httpx.ConnectError("x"), httpx.ReadTimeout("x")])
def test_transport_errors_are_unavailable(exc):
    respx.post(URL).mock(side_effect=exc)
    with pytest.raises(PlantnetUnavailable):
        _identify()


@respx.mock
def test_errors_never_contain_the_api_key():
    respx.post(URL).mock(side_effect=httpx.ConnectError(f"cannot reach {URL}?api-key={KEY}"))
    with pytest.raises(PlantnetUnavailable) as exc:
        _identify()
    assert KEY not in str(exc.value)
    assert exc.value.__cause__ is None and exc.value.__suppress_context__
