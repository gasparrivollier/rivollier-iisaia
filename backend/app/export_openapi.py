"""Write the API's OpenAPI schema to backend/openapi.json, the client's contract.

Run `uv run python -m app.export_openapi` after changing any route or schema, and commit
the result. tests/test_openapi_snapshot.py fails while the committed file is stale.
"""

import json
from pathlib import Path

from app.main import create_app

OPENAPI_PATH = Path(__file__).resolve().parents[1] / "openapi.json"


def render() -> str:
    return json.dumps(create_app().openapi(), indent=2, sort_keys=True) + "\n"


if __name__ == "__main__":
    OPENAPI_PATH.write_text(render())
    print(f"wrote {OPENAPI_PATH}")
