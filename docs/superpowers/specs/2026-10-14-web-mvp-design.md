# Yvoty Web MVP (Phase 0) - Design

Date: 2026-10-14. Status: awaiting review. Related: `docs/architecture.md` (decisions, data model, phased order), `docs/roadmap.md`, `docs/plantnet-api.md`.

## Goal

A web-only MVP of Yvoty: a user registers, logs in, uploads 1-5 photos of a plant with organ tags, sees ranked Pl@ntNet identification results, saves a result to their diary/garden, and sees saved plants after reloading. Verified end to end with Playwright against the full stack.

Out of scope: Android, quota UI, region-map real data, animated garden, webcam capture, email verification / password reset / social login.

## Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Scope | Original Phases 0-4 on web, as five vertical slices |
| Platform | Flutter Web only for this phase |
| e2e | Playwright (TypeScript), semantic locators via Flutter semantics |
| Pl@ntNet in tests | Backend `PLANTNET_BASE_URL` points to a local fake server; real API only in a manual smoke run |
| Photo input | File picker (multiple), no webcam |
| Pl@ntNet project | `all` |
| Layout | Top-level `e2e/`; Dart API client hand-written in `client/lib/data/api`, checked against the committed `backend/openapi.json` (codegen deferred; decided in slice 0.2) |
| Container runtime | `compose.yaml`, run with podman |

## Slices

Each slice ships with its own Playwright spec before the next starts.

| Slice | Scope | Done when |
|---|---|---|
| 0.1 Scaffold | `backend/` skeleton (health check, DB, `users` migration), `compose.yaml`, Flutter Web build served statically, `e2e/` project, `fake-plantnet/` | Playwright loads the app and sees the Diary; `/health` responds |
| 0.2 Auth | `POST /auth/register`, `/auth/login`, JWT dependency, login/register screens, token in browser storage | Register + login round-trip against the real backend; invalid/missing JWT rejected |
| 0.3 Single-photo identify | `POST /identify` (1 image), MinIO upload, Pl@ntNet call, persisted `identifications`, `identification_images`, `identification_results` | Upload a photo, see results in the UI, rows exist in DB |
| 0.4 Multi-shot + organs | Up to 5 images, organ tags, client + server validation, `predictedOrgans` feedback | Invalid sets rejected on both sides; organ feedback visible |
| 0.5 Save to garden | `plants`, `garden_items`, `POST /garden`, `GET /garden`, Diary shows real plants | Save a plant, reload, it is still in the Diary |

## Repo layout

```
backend/        FastAPI, SQLAlchemy, Alembic; uv + pyproject.toml, Python 3.12/3.13; pytest
client/         Flutter Web; client/lib/data/api generated from backend OpenAPI
e2e/            Playwright project (own package.json); globalSetup brings the stack up
fake-plantnet/  Tiny server replaying docs/examples/plantnet-identify-response.json
compose.yaml    postgres + minio + backend + fake-plantnet (podman compose)
```

Backend internals follow `docs/architecture.md` (routers, services, models, schemas, core). Flutter is built with `flutter build web` and served statically for e2e; `flutter run -d chrome` is used for development. Test builds call `SemanticsBinding.instance.ensureSemantics()` so Playwright can use `getByRole`/`getByText`, and key widgets carry `Semantics(identifier: ...)`.

## Components

- **plantnet_client** (backend): sole owner of the Pl@ntNet key and HTTP call; base URL from `PLANTNET_BASE_URL` (default real API). Interface: `identify(images, organs) -> PlantnetResponse`. Depends on httpx and settings only.
- **storage** (backend): S3-protocol adapter (boto3) over MinIO; `put(key, bytes)`, `presign(key)`.
- **auth / deps** (backend): password hashing, JWT issue/verify, `get_current_user`.
- **Client repositories**: `IdentifyRepository`, `PlantsRepository`, `RegionRepository` interfaces stay; HTTP implementations are added beside the existing fakes, which remain as test doubles. Region stays on its fake in this phase.
- **fake-plantnet**: returns the recorded response for any valid identify call; can return 429 on demand for error-path tests.

## Data flow

1. Client validates (<=5 images, JPEG/PNG, >=800x800, organ count == image count) to avoid wasting quota.
2. Client sends `POST /identify` multipart with JWT.
3. Backend re-validates, stores images in MinIO, calls Pl@ntNet project `all`, persists the three identification tables (including `version`), returns a trimmed result.
4. Saving is a separate `POST /garden` referencing the identification and chosen result.
5. Images are served back via presigned URLs.

## Error handling

- Invalid input: 4xx from the backend before any Pl@ntNet call.
- Pl@ntNet 429: passed through with `Retry-After`; no silent retry.
- Client: 401 returns to login; 422 shows validation messages; 429 shows a retry message. Quota indicator is a later phase.

## Testing

- **Backend**: pytest unit tests (httpx test client, plantnet_client against fake-plantnet or respx); integration tests with Postgres + MinIO containers and Alembic migrations applied.
- **Flutter**: widget/unit tests; existing `app_flow_test.dart` stays as a smoke test; fakes used as doubles.
- **Playwright**: one spec per slice against the full stack with fake-plantnet; includes error paths (invalid image set, 429, bad JWT).
- **Manual**: one smoke run against the real Pl@ntNet with the real key. Automated tests never spend quota.
- **CI** (later): `flutter analyze`, `flutter test`, `ruff`, `pytest` on push; Playwright on schedule/manual.

## Open items

None blocking. Deployment target stays undecided.
