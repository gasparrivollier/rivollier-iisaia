# Yvoty — Feature Map

Snapshot as of 2026-10-14. Companion to `docs/architecture.md` (decisions + phased build order).

## Current (built)

**Flutter client** (`client/lib`, Android + Web, go_router + provider) — all running on **in-memory fakes**, no backend yet.

| Area | State |
|---|---|
| Diary (home) | List of catalogued specimens (`diary_screen.dart`) |
| Capture | Multi-photo capture UI, "n/5 photos" (`capture_screen.dart`) |
| Results | Ranked candidates, best match, score bars (`results_screen.dart`) |
| Plant detail | Specimen view + notes (`plant_detail_screen.dart`) |
| Region map | Argentina province map via `CustomPainter` + bundled `ar-lowpoly.geojson`, coverage per province (`features/region/`) |
| Shared UI | Theme, top bar, pills, journal card, sketch placeholder |
| Tests | One widget test walking all 5 screens (`test/app_flow_test.dart`) |
| Repositories | `FakeIdentifyRepository`, `FakePlantsRepository`, `FakeRegionRepository` behind interfaces |

**Data / research**
- Pl@ntNet API reference (`docs/plantnet-api.md`) + scripts (`scripts/fetch_plantnet_species.py`, `test_plantnet.py`)
- Native-species dataset scraped from nativas.lanacion.com.ar: 265 species, ecoregions, care/bloom detail, photo credits (`docs/nativas-source.md`, `docs/examples/`)
- UI designs (`design/yvoty-ui/`), architecture + drawio diagram

## Pending

### Phase 0: Web MVP (current focus, redefined 2026-10-14)

Web only (Flutter Web + FastAPI + Postgres + MinIO), with **Playwright** e2e tests and Pl@ntNet stubbed in all automated tests. Built as five vertical slices; each ships with its own Playwright test before the next starts. Android is deferred.

| Slice | Scope | Done when |
|---|---|---|
| 0.1 Scaffold | `backend/` (FastAPI, `uv`), `compose.yaml` (podman), Flutter Web served locally, Playwright project | Smoke test loads the app and sees the Diary; health check responds |
| 0.2 Auth | Register/login/JWT, login screens, browser token storage | Round-trip against real backend; bad JWT rejected |
| 0.3 Single-photo identify | `POST /identify`, MinIO upload, Pl@ntNet call, persisted results | Upload a photo, see results in UI, rows in DB |
| 0.4 Multi-shot + organs | Up to 5 photos, organ tags, validation, `predictedOrgans` | Invalid sets rejected client + server; organ feedback shown |
| 0.5 Save to garden | `plants`/`garden_items`, `POST/GET /garden`, real Diary | Save a plant, reload, still in Diary; fakes kept as test doubles |

Status: spec written (docs/superpowers/specs/2026-10-14-web-mvp-design.md); slice 0.1 plan in docs/superpowers/plans/2026-10-14-slice-0.1-scaffold.md.

### Later phases

1. Quota/error-cost hardening (`/v2/quota/daily`, 429/`Retry-After`, quota indicator)
2. Android target (emulator, licenses, Android e2e)
3. Region map with real data: load nativas into Postgres, ecoregion-to-province mapping, real coverage queries
4. Animated virtual garden (`CustomPainter`, drag-to-rearrange)

## Suggested (not yet planned)

- **Pokedex view**: browse the full species catalog (Pl@ntNet / nativas) with "seen vs unseen" state; the core of the "pokedex" idea
- **Species detail from nativas data**: care, bloom calendar, fauna, ambiente, propagation shown on plant detail
- **Offline / local cache** of diary and last identification
- **Camera permissions + real image picker** (Android/Web differences)
- **Diseases endpoint** (Pl@ntNet `/diseases`) as a "diagnose" flow
- **Garden care reminders** (watering/bloom season from nativas care data)
- **Image attribution screen** (required for Pl@ntNet / nativas photo credits)
- **CI**: `flutter analyze`, `flutter test`, `ruff`, `pytest` on push; Playwright on schedule/manual
- **Backend tests + OpenAPI-driven client DTOs**
- **Deployment target decision** (intentionally open in architecture.md)

## Suggested next step

Finish the Phase 0 design and write its spec, then plan and build slice 0.1 (scaffold + Playwright smoke test) so the fakes can be replaced one repository at a time.
