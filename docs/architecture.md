# Yvoty Architecture

Plant-identification "pokedex" + virtual garden app. This document records the system architecture decided for the project: client/backend/data stack, repo layout, data model, auth, image storage, and build order. It's the reference other design/implementation decisions should build on.

Related: `docs/plantnet-api.md` (Pl@ntNet API reference this architecture integrates with).

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
│   ├── pyproject.toml
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
├── docker-compose.yml           # postgres + minio + backend, for local dev
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

## Auth

Simple email+password with FastAPI-issued JWT — no managed auth vendor (Auth0/Firebase/Supabase Auth), since that's extra integration surface a custom backend doesn't need. `passlib` (bcrypt) for hashing, `pyjwt`/`python-jose` for tokens, `POST /auth/register`, `POST /auth/login`, and a `get_current_user` FastAPI dependency guarding protected routes. No email verification / password reset / social login for v1 — explicit simplification, not an oversight.

## Image storage

**MinIO, self-hosted, in both dev and production.** It speaks the S3 API (via `boto3`/`aioboto3`, so `storage.py` only ever targets the S3 *protocol*, never a MinIO-specific SDK) — not DB blobs (bloats Postgres) and not local disk (breaks on any multi-instance or ephemeral-filesystem deployment). Local dev runs a MinIO container in `docker-compose.yml` alongside Postgres; production runs the same MinIO image on whatever host is eventually chosen, configured via `.env` (endpoint/credentials/bucket). Same code path in both environments — only the endpoint changes. If a managed provider (S3/R2/B2/Spaces) is ever preferred later, it's a drop-in swap since the client code only depends on the S3 protocol. Only `storage_key` is stored in Postgres; images are served via presigned URLs for now (no CDN yet).

## Phased build order

0. **Scaffolding** — `docker-compose.yml` (Postgres + MinIO + backend), FastAPI skeleton (health check, DB connection, initial `users` migration), Flutter skeleton (`flutter create` for android+web, basic nav shell).
1. **Auth vertical slice** — backend register/login/JWT; Flutter login/register screens + token storage + an authenticated test screen.
2. **Single-photo identify → result view** — backend `POST /identify` (one image, no organ tagging yet) calling Pl@ntNet and persisting `identifications`/`identification_images`/`identification_results`; Flutter camera/gallery picker + results display. This is the smallest slice proving the full chain end-to-end.
3. **Multi-shot capture + organ tagging** — up to 5 images, organ tags, client-side pre-validation, `predictedOrgans` feedback in UI.
4. **Save to garden + list view** — `plants`/`garden_items` tables, `POST /garden`, `GET /garden`, plain list/grid UI (no animation yet).
5. **Quota/error-cost hardening** — `GET /v2/quota/daily` passthrough, 429/`Retry-After` handling, remaining-quota indicator in UI.
6. **Animated virtual garden view** — Flutter canvas-based rendering (CustomPainter) of `garden_items`, drag-to-rearrange writing back `pos_x`/`pos_y`/`layout_data`. Deliberately last: highest-effort, most speculative piece; everything before it is required plumbing regardless of how the visualization evolves.

## Verification per phase

Since this is scaffolding work, "verification" means confirming each phase's vertical slice actually works end-to-end before moving to the next:
- **Phase 0**: `docker-compose up` brings up Postgres + MinIO + backend; FastAPI health check responds; `flutter run -d chrome` and `flutter run -d android` both launch the nav shell.
- **Phase 1**: register + login round-trip works from the Flutter app against the real backend (not mocked); a protected route rejects missing/invalid JWTs.
- **Phase 2**: a real photo captured/picked in the Flutter app produces a real Pl@ntNet identification, visible in the UI, with a corresponding row in `identifications`/`identification_images`/`identification_results` in Postgres — the critical end-to-end proof point for the whole stack choice.
- **Each later phase**: demoable on both Android and Web from the same Flutter codebase, since validating that parity holds is the reason Flutter was chosen.
