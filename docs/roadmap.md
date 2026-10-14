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

## Pending (decided in architecture.md, not started)

Build order from the architecture doc:

0. **Scaffolding**: `backend/` (FastAPI + Postgres + MinIO), `docker-compose.yml`, `.env` wiring. *No backend directory exists yet.*
1. **Auth**: register/login/JWT, login screens, token storage
2. **Real identify**: `POST /identify` proxying Pl@ntNet, persisting identifications; replace `FakeIdentifyRepository`
3. **Multi-shot + organ tagging**: client-side validation (≤5 images, JPEG/PNG, ≥800px), `predictedOrgans` feedback
4. **Save to garden**: `plants` / `garden_items`, `POST/GET /garden`; replace `FakePlantsRepository`
5. **Quota hardening**: `/v2/quota/daily` passthrough, 429 / `Retry-After`, remaining-quota indicator
6. **Animated virtual garden**: `CustomPainter` view, drag to rearrange (`pos_x`/`pos_y`/`layout_data`)

Region map follow-ups:
- Load nativas dataset into Postgres (`region_species`)
- Build the ecoregion → province mapping table
- Swap `FakeRegionRepository` for real coverage queries (user plants joined to `region_species`)

## Suggested (not yet planned)

- **Fix `.gitignore`**: line 19 `lib/` (Python template) ignores `client/lib`, so the whole Flutter source is untracked. Change to `/lib/` or add `!client/lib/`. *Highest priority.*
- **Pokedex view**: browse the full species catalog (Pl@ntNet / nativas) with "seen vs unseen" state; the core of the "pokedex" idea
- **Species detail from nativas data**: care, bloom calendar, fauna, ambiente, propagation shown on plant detail
- **Offline / local cache** of diary and last identification
- **Camera permissions + real image picker** (Android/Web differences)
- **Diseases endpoint** (Pl@ntNet `/diseases`) as a "diagnose" flow
- **Garden care reminders** (watering/bloom season from nativas care data)
- **Image attribution screen** (required for Pl@ntNet / nativas photo credits)
- **CI**: `flutter analyze` + tests on push
- **Backend tests + OpenAPI-driven client DTOs**
- **Deployment target decision** (intentionally open in architecture.md)

## Suggested next step

Fix `.gitignore` and commit `client/lib`, then start Phase 0 (backend scaffold) so the fakes can be replaced one repository at a time.
