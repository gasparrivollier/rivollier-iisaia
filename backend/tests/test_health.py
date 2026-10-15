from fastapi.testclient import TestClient
from sqlalchemy.exc import OperationalError

from app.db import get_db


def test_health_ok_when_db_answers(client_with_db):
    res = client_with_db.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok", "db": "ok"}


def test_health_503_when_db_raises(app):
    class _DownSession:
        def execute(self, *_args, **_kwargs):
            raise OperationalError("SELECT 1", {}, Exception("connection refused"))

    def _down_db():
        yield _DownSession()

    app.dependency_overrides[get_db] = _down_db
    with TestClient(app) as client:
        res = client.get("/health")
    app.dependency_overrides.clear()
    assert res.status_code == 503
    assert res.json() == {"status": "degraded", "db": "unreachable"}
