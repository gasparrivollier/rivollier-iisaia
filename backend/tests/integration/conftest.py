import pytest
from alembic import command
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from app.db import get_db, make_engine
from app.main import create_app
from tests.integration.alembic_helpers import alembic_cfg


@pytest.fixture
def migrated_url(test_db_url) -> str:
    """yvoty_test at head with an empty users table.

    Function-scoped on purpose: test_migrations downgrades to base after each of its tests.
    """
    command.upgrade(alembic_cfg(test_db_url), "head")
    engine = create_engine(test_db_url)
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE users RESTART IDENTITY CASCADE"))
    engine.dispose()
    return test_db_url


@pytest.fixture
def api(migrated_url):
    app = create_app()
    engine = make_engine(migrated_url)
    session_factory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def _db():
        with session_factory() as s:
            yield s

    app.dependency_overrides[get_db] = _db
    with TestClient(app) as client:
        yield client
    engine.dispose()
