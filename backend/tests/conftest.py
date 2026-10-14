import pytest
from fastapi.testclient import TestClient

from app.db import get_db
from app.main import create_app


class _OkSession:
    def execute(self, *_args, **_kwargs):
        return None


@pytest.fixture
def app():
    return create_app()


@pytest.fixture
def client_with_db(app):
    """TestClient whose DB dependency always succeeds (no Postgres needed)."""

    def _ok_db():
        yield _OkSession()

    app.dependency_overrides[get_db] = _ok_db
    with TestClient(app) as client:
        yield client
    app.dependency_overrides.clear()
