import pytest

from app.services.identifications import persist_identification
from app.services.plantnet_client import PlantnetResponse
from tests.fakes import RECORDED, RecordingSession


def _response() -> PlantnetResponse:
    return PlantnetResponse.model_validate(RECORDED)


def test_persists_one_image_and_every_ranked_result():
    db = RecordingSession()
    ident = persist_identification(
        db,
        user_id=3,
        project="all",
        response=_response(),
        image_key="identifications/3/a.png",
        organ="auto",
    )
    assert db.added == [ident] and db.commits == 1
    assert (ident.user_id, ident.project, ident.id) == (3, "all", 7)
    assert ident.best_match == "Murraya paniculata (L.) Jack"
    assert ident.remaining_requests_at_call == 497
    assert ident.plantnet_version == "2026-03-20 (7.5)"

    [image] = ident.images
    assert (image.storage_key, image.organ, image.sort_order) == (
        "identifications/3/a.png",
        "auto",
        0,
    )
    assert (image.predicted_organ, image.predicted_organ_score) == ("flower", 0.77573)

    assert [r.rank for r in ident.results] == list(range(1, 11))
    top = ident.results[0]
    assert top.score == 0.88926
    assert top.scientific_name == "Murraya paniculata (L.) Jack"
    assert top.scientific_name_without_author == "Murraya paniculata"
    assert (top.genus, top.family) == ("Murraya", "Rutaceae")
    assert top.common_names == ["Orange Jasmine", "Orange jessamine", "Mock orange"]
    assert (top.gbif_id, top.powo_id) == ("5421335", "774441-1")


def test_tolerates_missing_optional_fields():
    resp = PlantnetResponse.model_validate(
        {
            "results": [
                {
                    "score": 0.4,
                    "species": {
                        "scientificName": "A b L.",
                        "scientificNameWithoutAuthor": "A b",
                    },
                }
            ]
        }
    )
    ident = persist_identification(
        RecordingSession(), user_id=1, project="all", response=resp, image_key="k", organ="auto"
    )
    r = ident.results[0]
    assert (r.genus, r.family, r.gbif_id, r.powo_id, r.common_names) == (
        None,
        None,
        None,
        None,
        [],
    )
    assert ident.images[0].predicted_organ is None
    assert ident.best_match is None and ident.plantnet_version is None


def test_rolls_back_and_reraises_when_commit_fails():
    db = RecordingSession(fail_on_commit=RuntimeError("db down"))
    with pytest.raises(RuntimeError):
        persist_identification(
            db, user_id=1, project="all", response=_response(), image_key="k", organ="auto"
        )
    assert db.rollbacks == 1 and db.commits == 0
