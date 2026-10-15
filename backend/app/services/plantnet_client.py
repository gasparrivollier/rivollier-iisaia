"""Sole owner of the Pl@ntNet API key and the HTTP call (docs/plantnet-api.md).

The key travels in the query string, so exception messages here are fixed strings and the
original httpx error (whose text can include the URL) is suppressed with `from None`.
"""

import httpx
from fastapi import Depends
from pydantic import BaseModel, ValidationError

from app.config import Settings, get_settings


class PlantnetError(Exception):
    pass


class PlantnetRateLimited(PlantnetError):
    def __init__(self, retry_after: str | None):
        super().__init__("Pl@ntNet rate limit reached")
        self.retry_after = retry_after


class PlantnetNoPlant(PlantnetError):
    """Pl@ntNet answered 404 'Species not found': the photo does not look like a plant."""


class PlantnetUnavailable(PlantnetError):
    pass


class NamedTaxon(BaseModel):
    scientificNameWithoutAuthor: str


class ExternalId(BaseModel):
    id: int | str


class Species(BaseModel):
    scientificName: str
    scientificNameWithoutAuthor: str
    genus: NamedTaxon | None = None
    family: NamedTaxon | None = None
    commonNames: list[str] = []


class Candidate(BaseModel):
    score: float
    species: Species
    gbif: ExternalId | None = None
    powo: ExternalId | None = None


class PredictedOrgan(BaseModel):
    organ: str
    score: float


class PlantnetResponse(BaseModel):
    bestMatch: str | None = None
    results: list[Candidate]
    predictedOrgans: list[PredictedOrgan] = []
    version: str | None = None
    remainingIdentificationRequests: int | None = None


class PlantnetClient:
    def __init__(self, base_url: str, api_key: str, timeout: float = 30.0):
        self._base_url = base_url.rstrip("/")
        self._api_key = api_key
        self._timeout = timeout

    def identify(
        self,
        *,
        project: str,
        filename: str,
        content: bytes,
        content_type: str,
        organ: str = "auto",
    ) -> PlantnetResponse:
        try:
            res = httpx.post(
                f"{self._base_url}/v2/identify/{project}",
                params={"api-key": self._api_key},
                files={"images": (filename, content, content_type)},
                data={"organs": organ},
                timeout=self._timeout,
            )
        except httpx.HTTPError:
            raise PlantnetUnavailable("Could not reach Pl@ntNet") from None
        if res.status_code == 429:
            raise PlantnetRateLimited(res.headers.get("Retry-After"))
        if res.status_code == 404:
            raise PlantnetNoPlant("No plant detected")
        if res.status_code != 200:
            raise PlantnetUnavailable(f"Pl@ntNet answered HTTP {res.status_code}")
        try:
            return PlantnetResponse.model_validate(res.json())
        except (ValueError, ValidationError):
            raise PlantnetUnavailable("Pl@ntNet sent an unexpected response") from None


def get_plantnet_client(settings: Settings = Depends(get_settings)) -> PlantnetClient:
    return PlantnetClient(settings.plantnet_base_url, settings.plantnet_api_key)
