"""Fake Pl@ntNet API for tests: replays a recorded /v2/identify response.

Never spends real quota. Point the backend's PLANTNET_BASE_URL here.
"""

import copy
import json
import os
from datetime import UTC, datetime, timedelta
from email.utils import format_datetime
from pathlib import Path

from fastapi import FastAPI, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

DEFAULT_RECORDED = (
    Path(__file__).resolve().parents[1] / "docs/examples/plantnet-identify-response.json"
)


class NextStatus(BaseModel):
    status: int


def _error(status: int, message: str, headers: dict[str, str] | None = None) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={"statusCode": status, "error": "Fake", "message": message},
        headers=headers,
    )


def _next_utc_midnight() -> str:
    now = datetime.now(UTC)
    midnight = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return format_datetime(midnight, usegmt=True)


def create_app(recorded_path: Path | None = None) -> FastAPI:
    path = recorded_path or Path(os.environ.get("RECORDED_RESPONSE", DEFAULT_RECORDED))
    recorded = json.loads(path.read_text())
    state: dict[str, int | None] = {"next_status": None}
    app = FastAPI(title="fake-plantnet")

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.post("/_control/next-status")
    def set_next_status(body: NextStatus) -> dict[str, int]:
        state["next_status"] = body.status
        return {"next_status": body.status}

    @app.post("/v2/identify/{project}")
    async def identify(
        project: str, request: Request, api_key: str | None = Query(None, alias="api-key")
    ):
        if not api_key:
            return _error(401, "Missing api-key")
        forced, state["next_status"] = state["next_status"], None
        if forced == 429:
            return _error(429, "Too Many Requests", {"Retry-After": _next_utc_midnight()})
        if forced is not None:
            return _error(forced, "Forced by test")
        form = await request.form()
        if not form.getlist("images"):
            return _error(400, "At least one image is required")
        body = copy.deepcopy(recorded)
        body["query"]["project"] = project
        return JSONResponse(
            body,
            headers={
                "RateLimit-Policy": '"identify";q=500;w=86400',
                "RateLimit": '"identify";r=499;t=3600',
            },
        )

    return app


app = create_app()
