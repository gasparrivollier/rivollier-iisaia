import pytest

from app.services.identifications import StoredImage, persist_identification
from app.services.plantnet_client import PlantnetResponse
from tests.fakes import RECORDED, RecordingSession


def _response(**overrides) -> PlantnetResponse:
    return PlantnetResponse.model_validate({**RECORDED, **overrides})


def _persist(db, images, response=None):
    return persist_identification(
        db,
        user_id=3,
        project="all",
        response=response or _response(),
        images=images,
    )


def test_persists_each_image_with_its_organ_and_positional_prediction():
    db = RecordingSession()
    ident = _persist(
        db,
        [
            StoredImage("identifications/3/a.png", "flower"),
            StoredImage("identifications/3/b.jpg", "leaf"),
            StoredImage("identifications/3/c.png", "auto"),
        ],
    )
    assert db.added == [ident] and db.commits == 1
    assert (ident.user_id, ident.project, ident.id) == (3, "all", 7)
    assert ident.best_match == "Murraya paniculata (L.) Jack"
    assert ident.remaining_requests_at_call == 497
    assert ident.plantnet_version == "2026-03-20 (7.5)"

    assert [(i.storage_key, i.organ, i.sort_order) for i in ident.images] == [
        ("identifications/3/a.png", "flower", 0),
        ("identifications/3/b.jpg", "leaf", 1),
        ("identifications/3/c.png", "auto", 2),
    ]
    # Recorded predictions are flower 0.77573, habit 0.40353, flower 0.82788 for the first three.
    assert [(i.predicted_organ, i.predicted_organ_score) for i in ident.images] == [
        ("flower", 0.77573),
        ("habit", 0.40353),
        ("flower", 0.82788),
    ]

    assert [r.rank for r in ident.results] == list(range(1, 11))
    top = ident.results[0]
    assert top.score == 0.88926
    assert top.scientific_name == "Murraya paniculata (L.) Jack"
    assert top.scientific_name_without_author == "Murraya paniculata"
    assert (top.genus, top.family) == ("Murraya", "Rutaceae")
    assert top.common_names == ["Orange Jasmine", "Orange jessamine", "Mock orange"]
    assert (top.gbif_id, top.powo_id) == ("5421335", "774441-1")


def test_fewer_predictions_than_photos_leaves_the_rest_null():
    resp = _response(predictedOrgans=[{"organ": "leaf", "score": 0.9}])
    ident = _persist(
        RecordingSession(),
        [StoredImage("k1", "auto"), StoredImage("k2", "auto"), StoredImage("k3", "auto")],
        resp,
    )
    assert [i.predicted_organ for i in ident.images] == ["leaf", None, None]
    assert [i.predicted_organ_score for i in ident.images] == [0.9, None, None]


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
    ident = _persist(RecordingSession(), [StoredImage("k", "auto")], resp)
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
        _persist(db, [StoredImage("k", "auto")])
    assert db.rollbacks == 1 and db.commits == 0
