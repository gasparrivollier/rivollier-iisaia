from app.export_openapi import OPENAPI_PATH, render

REGEN = "regenerate with: cd backend && uv run python -m app.export_openapi"


def test_committed_openapi_matches_the_app():
    assert OPENAPI_PATH.exists(), f"backend/openapi.json missing; {REGEN}"
    assert OPENAPI_PATH.read_text() == render(), f"backend/openapi.json is stale; {REGEN}"
