import time

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

from app.db import get_db, make_engine
from app.main import create_app

pytestmark = pytest.mark.integration


def _client_for(url: str) -> TestClient:
    app = create_app()
    session_factory = sessionmaker(bind=make_engine(url))

    def _db():
        with session_factory() as s:
            yield s

    app.dependency_overrides[get_db] = _db
    return TestClient(app)


def test_health_ok_against_real_postgres(test_db_url):
    with _client_for(test_db_url) as client:
        res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok", "db": "ok"}


def test_health_returns_503_quickly_when_db_unreachable():
    # 10.255.255.1 is non-routable, so a missing connect_timeout would hang far past 5s.
    with _client_for("postgresql+psycopg://x:y@10.255.255.1:5432/nope") as client:
        start = time.monotonic()
        res = client.get("/health")
        elapsed = time.monotonic() - start
    assert res.status_code == 503
    assert elapsed < 5
