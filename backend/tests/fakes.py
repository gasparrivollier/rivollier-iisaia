import json
from pathlib import Path

from app.models import Identification
from app.services.plantnet_client import PlantnetResponse

RECORDED = json.loads(
    (
        Path(__file__).resolve().parents[2] / "docs/examples/plantnet-identify-response.json"
    ).read_text()
)


class FakePlantnet:
    def __init__(self, error: Exception | None = None):
        self.error = error
        self.calls: list[dict] = []

    def identify(self, **kwargs) -> PlantnetResponse:
        self.calls.append(kwargs)
        if self.error is not None:
            raise self.error
        return PlantnetResponse.model_validate(RECORDED)


class FakeStorage:
    def __init__(self, error: Exception | None = None):
        self.error = error
        self.objects: dict[str, tuple[bytes, str]] = {}

    def put(self, key: str, data: bytes, content_type: str) -> None:
        if self.error is not None:
            raise self.error
        self.objects[key] = (data, content_type)

    def presign(self, key: str, expires: int = 3600) -> str:
        return f"http://files.test/{key}?sig=1"


class RecordingSession:
    """Stand-in for a SQLAlchemy Session that records what the code under test does."""

    def __init__(self, fail_on_commit: Exception | None = None):
        self.fail_on_commit = fail_on_commit
        self.added: list = []
        self.commits = 0
        self.rollbacks = 0

    def add(self, obj) -> None:
        self.added.append(obj)

    def commit(self) -> None:
        if self.fail_on_commit is not None:
            raise self.fail_on_commit
        self.commits += 1
        for obj in self.added:
            if isinstance(obj, Identification) and obj.id is None:
                obj.id = 7

    def rollback(self) -> None:
        self.rollbacks += 1

    def get(self, _model, _id):
        return None
