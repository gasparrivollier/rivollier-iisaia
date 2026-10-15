import json
from pathlib import Path

import httpx
import pytest
import respx

from app.services.plantnet_client import (
    ImagePart,
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


def _parts(n: int = 1) -> list[ImagePart]:
    organs = ["flower", "leaf", "auto", "fruit", "bark"]
    return [
        ImagePart(f"photo{i + 1}.png", f"PNGDATA{i + 1}".encode(), "image/png", organs[i])
        for i in range(n)
    ]


def _identify(client: PlantnetClient | None = None, n: int = 1):
    return (client or _client()).identify(project="all", images=_parts(n))


@respx.mock
def test_identify_posts_one_file_and_one_organ_per_image_in_order():
    route = respx.post(URL).mock(return_value=httpx.Response(200, json=RECORDED))
    result = _identify(n=3)

    req = route.calls.last.request
    assert req.url.params["api-key"] == KEY
    body = req.content
    for i in (1, 2, 3):
        assert f'name="images"; filename="photo{i}.png"'.encode() in body
        assert f"PNGDATA{i}".encode() in body
    assert body.count(b'name="organs"') == 3
    # organs travel in the same order as the files
    organ_values = [body.index(o) for o in (b"flower", b"leaf", b"auto")]
    assert organ_values == sorted(organ_values)

    assert len(result.results) == 10
    top = result.results[0]
    assert top.species.scientificNameWithoutAuthor == "Murraya paniculata"
    assert top.species.scientificName == "Murraya paniculata (L.) Jack"
    assert top.species.family.scientificNameWithoutAuthor == "Rutaceae"
    assert top.gbif.id == "5421335"
    assert result.version == "2026-03-20 (7.5)"
    assert result.remainingIdentificationRequests == 497
    assert [p.organ for p in result.predictedOrgans[:3]] == ["flower", "habit", "flower"]


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
