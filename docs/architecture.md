# Yvoty Architecture

Plant-identification "pokedex" + virtual garden app. This document records the system architecture decided for the project: client/backend/data stack, repo layout, data model, auth, image storage, and build order. It's the reference other design/implementation decisions should build on.

Related: `docs/plantnet-api.md` (Pl@ntNet API reference this architecture integrates with); `docs/nativas-source.md` (native-species-by-region data source for the region map feature).

## Decisions and why

- **Client: Flutter**, targeting Android + Flutter Web from one Dart codebase. Chosen specifically because Flutter's canvas-based rendering engine gives consistent, high-quality custom animations on *both* platforms — important because the app wants an animated virtual-garden view. React Native was the main alternative; it has excellent native Android performance too, but its web animations fall back to a different CSS/DOM-based system instead of one unified engine, which was the deciding factor.
- **Backend: Python FastAPI + PostgreSQL**, custom-built (not a BaaS like Supabase/Firebase). Backend language choice doesn't meaningfully affect performance here — the API is I/O-bound on Pl@ntNet's response time and DB queries, not compute-bound — so this was picked for simplicity/familiarity rather than raw speed. Deployment host is intentionally undecided for now; the design below avoids locking into one.
- **Third-party API: Pl@ntNet**, proxied through the backend — the Flutter client never calls Pl@ntNet directly. This keeps the `api-key` out of the shipped Android APK and Flutter Web bundle (both are trivially inspectable), and lets one backend request both call Pl@ntNet and persist the result to the user's account atomically.

## System architecture

```
Flutter Client (Android + Web)
        │  HTTPS + JWT bearer
        ▼
FastAPI Backend  ── owns PLANTNET_API_KEY (server-only) ──►  Pl@ntNet API
        │
        ├──► PostgreSQL   (users, identifications, plants, garden_items)
        └──► MinIO (self-hosted, S3-compatible)   (user-submitted plant photos)
```

**Identify request flow:**
1. Flutter does local pre-validation (image count ≤5, JPEG/PNG, ≥800×800px) *before* calling the backend — even failed Pl@ntNet calls cost a credit on the free plan (see `docs/plantnet-api.md`), so client-side validation avoids burning quota on requests guaranteed to fail.
2. Flutter → `POST /identify` on the backend, multipart images + organ tags, JWT in `Authorization` header.
3. Backend re-validates, uploads images to object storage, calls `POST https://my-api.plantnet.org/v2/identify/{project}` server-side with the API key.
4. Backend parses the response, persists it (see data model below), and returns a trimmed result to the client.
5. Saving a result into the user's garden is a separate, explicit step (`POST /garden`) — not automatic on identify, so browsing results doesn't force garden clutter.

**Quota/error-cost handling in the backend** (per `docs/plantnet-api.md`):
- Read `RateLimit`/`RateLimit-Policy` response headers on every Pl@ntNet call; expose remaining quota via a passthrough of `GET /v2/quota/daily`.
- On `429`, surface `Retry-After` to the client rather than retrying silently.
- Backend mirrors the same pre-validation Flutter does (image count/type/size, organ-count-matches-image-count) and rejects malformed requests with a 4xx *before* calling Pl@ntNet.
- Store the `version` field from each response alongside the saved identification, for reproducibility/audit.

## Repo layout

```
yvoty/
├── docs/                     # plantnet-api.md, architecture.md (this file)
├── backend/
│   ├── pyproject.toml          # managed with uv; Python pinned to 3.12/3.13
│   ├── alembic/               # DB migrations
│   ├── app/
│   │   ├── main.py            # FastAPI app factory
│   │   ├── config.py          # pydantic-settings, reads .env
│   │   ├── db.py               # SQLAlchemy engine/session
│   │   ├── models/              # user.py, identification.py, garden.py
│   │   ├── schemas/              # Pydantic request/response models
│   │   ├── routers/               # auth.py, identify.py, plants.py, garden.py
│   │   ├── services/
│   │   │   ├── plantnet_client.py  # sole owner of the Pl@ntNet api-key + HTTP call
│   │   │   └── storage.py           # S3-compatible object storage adapter
│   │   └── core/                     # security.py (hashing/JWT), deps.py (get_current_user, get_db)
│   └── tests/
├── client/                     # Flutter app (flutter create, android + web targets)
│   └── lib/
│       ├── main.dart
│       ├── features/            # auth/, identify/, plants/, garden/
│       ├── data/                 # API client, DTOs
│       └── core/                  # theming, routing, shared widgets
├── compose.yaml                 # postgres + minio + backend, for local dev (runtime-neutral: docker or podman compose)
├── .env.example / .env          # already exist
```

`backend/` and `client/` are plain sibling directories, each with their own dependency manager (`pyproject.toml`, `pubspec.yaml`), rather than a monorepo build tool (Melos/Nx) — more conventional to teach and read for a course repo.

## Data model (Postgres, first cut)

- **`users`** — id, email (unique), password_hash, display_name, created_at.
- **`identifications`** — one row per Pl@ntNet `/identify` call: user_id, project, best_match, `remaining_requests_at_call` (snapshot of `remainingIdentificationRequests`), `plantnet_version` (the `version` field), created_at.
- **`identification_images`** — the up-to-5 submitted photos per call: identification_id, storage_key, organ (submitted tag), predicted_organ + predicted_organ_score (from `predictedOrgans`), sort_order.
- **`identification_results`** — ranked candidate species per call (`results[]`): identification_id, rank, score, scientific_name (+ without-author variant), genus, family, common_names (array/jsonb), gbif_id, powo_id.
- **`plants`** — a user's confirmed/saved plant: user_id, identification_id + identification_result_id (provenance — which call and which candidate was confirmed), nickname, scientific_name (denormalized at save time), cover_image_key, saved_at.
- **`garden_items`** — placement in the virtual garden view: user_id, plant_id (unique — one slot per saved plant), pos_x/pos_y (free-form coords), `layout_data jsonb` (escape hatch for scale/rotation/growth-stage etc. later without migrations), added_at.

Rationale: `identifications`/`identification_images`/`identification_results` record *every* call (browsed or not) for quota-usage history and reproducibility; `plants` is deliberately a separate "user chose to keep this" layer so browsing results doesn't clutter the garden; `garden_items` stays minimal with a jsonb escape hatch so future animated-layout mechanics aren't blocked by schema decisions made now.

### Region map addition (native species by province)

Supports the "collection progress by province" screen (`client/lib/features/region/`, ported from `design/yvoty-ui/05-Region-Map.html`):

- **`provinces`** — id, name, slug. Static reference data (Argentina's 24 provinces don't change); geometry itself ships as a bundled client asset (`ar-lowpoly.geojson`), not DB rows.
- **`region_species`** — id, province_id (FK), scientific_name, common_name, is_native. Curated reference/seed data, same category as the Pl@ntNet species catalog dump (`docs/examples/plantnet-species.csv`).
- Per-province **coverage** (`have`/`total` shown in the UI) is computed at query time by joining a user's `plants.scientific_name` against `region_species` for that province — no new junction table needed.

**Data source (resolved):** `nativas.lanacion.com.ar` (La Nación/Aves Argentinas/Revista Jardín) provides exactly the native-species-by-region data Pl@ntNet doesn't — ~265 species with scientific/common names, rich per-species detail, and region tags. Scraped into `docs/examples/nativas-species.csv` (id/name/ecoregiones/cover image) and `nativas-species-detail.jsonl` (full detail incl. family, description, care requirements, bloom calendar, fauna, and per-photo attribution) by `scripts/fetch_nativas_species.py`; full shape and scrape mechanics documented in `docs/nativas-source.md`.

**Wrinkle:** the site tags species by **ecoregion** (17 ecological zones — Selva Paranaense, Yungas, Pampeana, Puna, etc.), not by the 24 political provinces `region_species`/`ar-lowpoly.geojson` use — an ecoregion doesn't map 1:1 onto the provinces it overlaps (e.g. a Yungas-only species spans parts of Jujuy/Salta/Tucumán, not their entirety). Decision: `region_species` (or a new `ecoregion_species` table) stores ecoregión as scraped — not discarded, not replaced — with a separate static ecoregion→province(s) mapping table joined at query time to keep serving the existing province-based map screen. Populating the mapping table and loading the scraped dataset into Postgres remains a **follow-up task**; this pass only produced and documented the source dataset.

## Auth

Simple email+password with FastAPI-issued JWT — no managed auth vendor (Auth0/Firebase/Supabase Auth), since that's extra integration surface a custom backend doesn't need. `passlib` (bcrypt) for hashing, `pyjwt`/`python-jose` for tokens, `POST /auth/register`, `POST /auth/login`, and a `get_current_user` FastAPI dependency guarding protected routes. No email verification / password reset / social login for v1 — explicit simplification, not an oversight.

## Image storage

**MinIO, self-hosted, in both dev and production.** It speaks the S3 API (via `boto3`/`aioboto3`, so `storage.py` only ever targets the S3 *protocol*, never a MinIO-specific SDK) — not DB blobs (bloats Postgres) and not local disk (breaks on any multi-instance or ephemeral-filesystem deployment). Local dev runs a MinIO container in `compose.yaml` alongside Postgres; production runs the same MinIO image on whatever host is eventually chosen, configured via `.env` (endpoint/credentials/bucket). Same code path in both environments — only the endpoint changes. If a managed provider (S3/R2/B2/Spaces) is ever preferred later, it's a drop-in swap since the client code only depends on the S3 protocol. Only `storage_key` is stored in Postgres; images are served via presigned URLs for now (no CDN yet).

## Phased build order

**Redefined 2026-10-14: Phase 0 is a web-only MVP.** Android is deferred (it returns after the MVP, before the animated garden). The MVP is the original Phases 0-4 built as five vertical slices; each slice ships working, with its own Playwright e2e test, before the next starts. Phase 0 is architectural-sized; its formal spec and implementation plan live in `docs/superpowers/` once written.

**Phase 0 - Web MVP (Flutter Web + FastAPI + Postgres + MinIO)**

- **0.1 Scaffold** - `backend/` (FastAPI, `uv`, health check, DB connection, initial `users` migration), `compose.yaml` (Postgres + MinIO via podman), Flutter Web served locally, Playwright project, and a smoke test that loads the app and sees the Diary.
- **0.2 Auth** - backend register/login/JWT; Flutter login/register screens, browser token storage, protected route rejecting bad tokens.
- **0.3 Single-photo identify** - `POST /identify` stores the photo in MinIO, calls Pl@ntNet, persists `identifications`/`identification_images`/`identification_results`; Flutter picker + results display. Smallest slice proving the whole chain.
- **0.4 Multi-shot + organ tagging** - up to 5 images, organ tags, client + server validation, `predictedOrgans` feedback in the UI.
- **0.5 Save to garden + list** - `plants`/`garden_items`, `POST/GET /garden`, Diary shows real saved plants. Fakes replaced by real repositories and kept as test doubles.

**Later phases**

1. **Quota/error-cost hardening** - `GET /v2/quota/daily` passthrough, 429/`Retry-After` handling, remaining-quota indicator in UI.
2. **Android target** - emulator/device support, Android e2e, licenses and JDK setup.
3. **Region map, real data** - load nativas dataset, ecoregion-to-province mapping, real coverage queries.
4. **Animated virtual garden view** - Flutter canvas-based rendering (CustomPainter) of `garden_items`, drag-to-rearrange writing back `pos_x`/`pos_y`/`layout_data`. Deliberately last: highest-effort, most speculative piece; everything before it is required plumbing regardless of how the visualization evolves.

## Verification per phase

Since this is scaffolding work, "verification" means confirming each phase's vertical slice actually works end-to-end before moving to the next:
- **Phase 0 (web MVP)**: every slice 0.1-0.5 is verified by a passing Playwright test against the running stack (`podman compose up` for Postgres + MinIO + backend, Flutter Web served locally), with Pl@ntNet stubbed. Slice 0.1: health check responds and Playwright sees the Diary. Slice 0.2: register + login round-trip against the real backend; bad JWTs rejected. Slice 0.3: a real photo upload yields a stubbed-Pl@ntNet identification in the UI plus rows in the three identification tables. Slice 0.5: save a plant, reload, see it in the Diary.
- **Phase 1**: register + login round-trip works from the Flutter app against the real backend (not mocked); a protected route rejects missing/invalid JWTs.
- **Phase 2**: a real photo captured/picked in the Flutter app produces a real Pl@ntNet identification, visible in the UI, with a corresponding row in `identifications`/`identification_images`/`identification_results` in Postgres — the critical end-to-end proof point for the whole stack choice.
- **Each later phase**: demoable on Web; once the Android phase lands, also on Android from the same Flutter codebase, since validating that parity holds is the reason Flutter was chosen.

## Dev and test tooling

Decided 2026-10-14. Dev machine is Fedora with Podman (no Docker), Flutter 3.47, `uv`, Node, Android SDK + emulator.

### Environment decisions

- **Container runtime:** `compose.yaml` stays runtime-neutral; locally it runs with `podman compose` (`podman-compose` installed). No Docker-only features.
- **Backend Python:** managed with `uv` + `pyproject.toml`, pinned to **3.12 or 3.13** (system Python is 3.14, too new for some libraries). Not Poetry.
- **Targets:** Web only for the Phase 0 MVP; Android returns in its own later phase (the project still targets Android + Web overall). Linux desktop is intentionally unsupported (`flutter doctor` GTK warning is ignored).
- **GitHub access:** `gh` is not installed; use the GitHub MCP tools or plain git.
- **Secrets:** `.env` (git-ignored) holds `PLANTNET_API_KEY`; `.env.example` (tracked) holds placeholders only.

### API contract first

FastAPI generates the OpenAPI schema; the Dart DTOs/client are generated from it, so client and backend cannot drift. The client's repository interfaces (`IdentifyRepository`, `PlantsRepository`, `RegionRepository`) stay as the seam: real HTTP implementations are added next to the fakes, and the **fakes are kept as test doubles**.

### Test layers

| Layer | Tooling | Notes |
|---|---|---|
| Client unit + widget | `flutter_test`, `mocktail` | Per-repository unit tests, per-screen widget tests; existing `app_flow_test.dart` stays as the smoke test |
| Client e2e | **Playwright** (Node/TypeScript) driving Flutter Web in Chromium | Flutter semantics enabled in test builds (`ensureSemantics()`, `Semantics(identifier:)`) so tests use normal locators (`getByRole`, `getByText`). No chromedriver, no `integration_test`. Android e2e deferred to the Android phase |
| Backend unit | `pytest`, `httpx` (FastAPI test client), `respx` | Pl@ntNet is **always mocked** using `docs/examples/plantnet-identify-response.json`; tests never spend real quota |
| Backend integration | Postgres + MinIO containers (`testcontainers` or the compose stack), Alembic migrations applied | |
| Full-stack e2e | Playwright against the real backend + Postgres + MinIO, Pl@ntNet stubbed | Mirrors the per-phase verification above: register, identify, save, see in diary |
| CI | GitHub Actions: `flutter analyze`, `flutter test`, `ruff`, `pytest` on push; e2e on schedule/manual | |

### Local setup status

- Fixed: Flutter's `jdk-dir` pointed at a stale Android Studio flatpak path (hash changed after an update); repointed at the current JBR. Re-run `flutter config --jdk-dir=...` if Android Studio updates again.
- Deferred to the Android phase: `flutter doctor --android-licenses`. Chromedriver is no longer needed (Playwright manages its own browsers via `npx playwright install chromium`).
