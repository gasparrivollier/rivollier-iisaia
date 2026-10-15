from pydantic import BaseModel


class IdentifyImageOut(BaseModel):
    url: str
    organ: str
    predicted_organ: str | None
    predicted_organ_score: float | None
    sort_order: int


class IdentifyResultOut(BaseModel):
    rank: int
    score: float
    scientific_name: str
    scientific_name_without_author: str
    genus: str | None
    family: str | None
    common_names: list[str]
    gbif_id: str | None
    powo_id: str | None


class IdentifyResponse(BaseModel):
    identification_id: int
    project: str
    best_match: str | None
    remaining_requests: int | None
    images: list[IdentifyImageOut]
    results: list[IdentifyResultOut]
