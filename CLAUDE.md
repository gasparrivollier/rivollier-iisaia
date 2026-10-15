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
cd backend && uv run pytest -m integration   # needs compose postgres + minio up
cd backend && uv run ruff check . && uv run ruff format --check .
cd backend && uv run python -m app.export_openapi   # after API changes; commit backend/openapi.json
cd fake-plantnet && uv run pytest
cd client && flutter analyze && flutter test
cd client && flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:8000   # port must be in CORS_ORIGINS
cd e2e && npm ci && npx playwright install chromium   # first run only
cd e2e && npm test                    # builds Flutter web (E2E=true), brings stack up, runs Playwright
```

## Conventions

- Automated tests never call the real Pl@ntNet; the backend's `PLANTNET_BASE_URL` defaults to `http://fake-plantnet:8100` in compose.
- Container images are fully qualified (`docker.io/...`); MinIO uses `cgr.dev/chainguard/minio` because the official images are no longer published.
- DB: sync SQLAlchemy 2 + psycopg 3; schema changes only through Alembic migrations in `backend/alembic/versions/`.
- Flutter widgets that e2e tests target get `Semantics(identifier: '...')`; Playwright locates them via `[flt-semantics-identifier="..."]`. Semantics are forced on only in `--dart-define=E2E=true` builds.
- Each Phase 0 slice ships with its own Playwright spec in `e2e/tests/`.
- API contract: `backend/openapi.json` is committed and must match the app (`tests/test_openapi_snapshot.py`); the hand-written Dart client in `client/lib/data/api/` is checked against it by `client/test/api_contract_test.dart`.
- Auth: bearer JWT (HS256, PyJWT) from `/auth/login` or `/auth/register`; protect routes with `Depends(get_current_user)` (`app/core/deps.py`). The client keeps the token in shared_preferences (localStorage `flutter.auth_token` on web).
- e2e emails come from `uniqueEmail()` (`e2e/support/auth.ts`) because compose volumes persist between runs.
- Playwright types into Flutter fields via `fillField()` in `e2e/support/flutter.ts` (click, wait for the inner input to be focused, type, assert value) because typing right after the click can drop the first character.
- Identify: `POST /identify` (multipart field `image`, bearer JWT) runs validate → Pl@ntNet → MinIO → DB; rejected or failed requests leave no objects or rows. Photos: JPEG/PNG, ≤10 MB, both sides ≥800 px, checked on both sides (`app/services/image_validation.py`, `client/lib/data/photo_validation.dart`). Presigned photo URLs are signed against `S3_PUBLIC_URL`, not the in-compose MinIO host.
- `ApiClient` calls `onUnauthorized` on any 401 to a request that carried a token (wired to `AuthController.logout` in `main.dart`); screens just show their own errors.
- e2e reads DB state with `sql()` / `countRows()` (`e2e/support/db.ts`, psql inside the compose postgres container) and builds test images with `makePng()` (`e2e/support/images.ts`); fake-plantnet's one-shot `POST /_control/next-status` forces 429/5xx.
