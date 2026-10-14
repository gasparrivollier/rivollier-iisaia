import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

from app.config import get_settings
from app.db import get_db
from app.main import create_app

TEST_DB = "yvoty_test"


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


@pytest.fixture(scope="session")
def test_db_url() -> str:
    """Create (once) and return a URL for an isolated yvoty_test DB on the compose Postgres."""
    base = make_url(get_settings().database_url)
    admin = create_engine(base.set(database="postgres"), isolation_level="AUTOCOMMIT")
    with admin.connect() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": TEST_DB}
        ).scalar()
        if not exists:
            conn.execute(text(f'CREATE DATABASE "{TEST_DB}"'))
    admin.dispose()
    return base.set(database=TEST_DB).render_as_string(hide_password=False)
