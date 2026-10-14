# CLAUDE.md — Yvoty

Guidance for Claude Code when working in this repository.

## About this app

Yvoty is a plant-identification "pokedex" + virtual garden app, using the Pl@ntNet API for species identification. See `docs/plantnet-api.md` for the API reference.

## Layout

`backend/` (FastAPI, uv, Python 3.13), `client/` (Flutter, web-only for Phase 0), `fake-plantnet/` (replays a recorded Pl@ntNet response), `e2e/` (Playwright), `compose.yaml` (podman). Plans and specs: `docs/superpowers/`.

## Commands

```bash
podman compose up -d --build          # postgres, minio, fake-plantnet, backend (:8000)
podman compose down                   # add -v to wipe DB/MinIO volumes
cd backend && uv run pytest           # unit tests
cd backend && uv run pytest -m integration   # needs compose postgres up
cd backend && uv run ruff check . && uv run ruff format --check .
cd fake-plantnet && uv run pytest
cd client && flutter analyze && flutter test
cd e2e && npm ci && npx playwright install chromium   # first run only
cd e2e && npm test                    # builds Flutter web (E2E=true), brings stack up, runs Playwright
```

## Conventions

- Automated tests never call the real Pl@ntNet; the backend's `PLANTNET_BASE_URL` defaults to `http://fake-plantnet:8100` in compose.
- Container images are fully qualified (`docker.io/...`); MinIO uses `cgr.dev/chainguard/minio` because the official images are no longer published.
- DB: sync SQLAlchemy 2 + psycopg 3; schema changes only through Alembic migrations in `backend/alembic/versions/`.
- Flutter widgets that e2e tests target get `Semantics(identifier: '...')`; Playwright locates them via `[flt-semantics-identifier="..."]`. Semantics are forced on only in `--dart-define=E2E=true` builds.
- Each Phase 0 slice ships with its own Playwright spec in `e2e/tests/`.
