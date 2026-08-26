# Pl@ntNet API Reference (for Yvoty)

Summary of the Pl@ntNet API (https://my.plantnet.org/doc/) for use by agents and contributors working on the Yvoty "plant pokedex + virtual garden" app. This app will use Pl@ntNet as the plant identification backend.

Base URL: `https://my-api.plantnet.org`

Source docs browsed: getting-started (introduction, pro-plan, faq), api (openapi, identify, diseases, varieties, quota, contract, other, survey), references (using-images, changelog). Last checked 2026-08-26.

---

## 1. Authentication

- Every request needs an `api-key` query parameter (create an account at my.plantnet.org and generate a key).
- If exposing the key client-side (browser JS), configure CORS authorization by domain/IP in the account dashboard.
- No OAuth/bearer token scheme — it's a simple API-key-in-query-string model.

## 2. Core endpoint: Single-species identification

`POST /v2/identify/{project}`

**Path param**
- `project` — flora/referential id (get valid values from `/v2/projects`), or `all` for the default global model.

**Query params**
- `api-key` (required)
- `lang` — language for common names etc.
- `nb-results` — cap number of results (min 1)
- `include-related-images` — bool, return similar reference images per species
- `no-reject` — bool, don't reject non-plant images (see rejection behavior below)
- `detailed` — bool, include `otherResults` (genus/family level breakdown); disabled by default since 2025-09-23
- `type=legacy` — only for old/deprecated project models

**Body**: `multipart/form-data`
- `images` — up to 5 files, JPG/PNG only, total request ≤ 50MB, all images must be of the **same individual plant**
- `organs` — optional string array (`leaf`, `flower`, `fruit`, `bark`, `auto`); if provided, count must match `images` count; omit = all `auto`

**Response** (key fields):
```json
{
  "query": { "project": "...", "images": [...], "organs": [...] },
  "predictedOrgans": [{ "image": "...", "organ": "...", "score": 0.9 }],
  "language": "en",
  "bestMatch": "Genus species",
  "results": [
    {
      "score": 0.87,
      "species": {
        "scientificNameWithoutAuthor": "...",
        "scientificName": "...",
        "genus": { "...": "..." },
        "family": { "...": "..." },
        "commonNames": ["..."]
      },
      "gbif": { "id": "..." },
      "powo": { "id": "..." }
    }
  ],
  "otherResults": [],
  "version": "...",
  "remainingIdentificationRequests": 495
}
```
- `score` ranges 0–1 (as of the 2019 v2 API change; older docs may say 0–100).
- `results` sorted by descending confidence.
- `gbif.id` can be cross-referenced against the GBIF species API for extra data (vernacular names, etc).
- `remainingIdentificationRequests` doubles as a lightweight quota check.

**Rejection behavior**: non-plant images → `404 Species not found`. Pass `no-reject=true` to force plant predictions anyway (still 404s if literally no plant-shaped signal at any confidence).

## 3. Other identification endpoints

### Diseases (beta/limited species list)
- `GET /v2/diseases` — list identifiable diseases (`label`, `name` = EPPO code, `categories`)
- `POST /v2/diseases/identify` — same image/organ rules as above, plus `prefix` filter param
- Costs 1 credit, **shares the same quota** as single-species identify.

### Varieties (cultivars, beta/limited)
- `GET /v2/varieties` — list identifiable varieties
- `POST /v2/varieties/identify` — same shape; results grouped under parent species, variety images at `varieties[*].images`
- Costs 1 credit, shares the identify quota.

### Multi-species survey (beta, limited access — plot/drone imagery)
- `GET/POST /v2/cost/survey/{project}` — estimate credit cost before running (accepts image dimensions like `"3200x2400"` instead of a file)
- `POST /v2/survey/tiles/{project}` — tiles a single large image (quadrat/plot photo, ideally 0.25–1m², overhead shot) and runs identify per tile
- Single image only (JPG/PNG, ≤50MB), no legacy projects.
- Notable params: `tile_size` (min 518px), `tile_stride`, `multi_scale`, `size_factor`, `pyramid`, `min_score`, `max_rank`, `show_species/genus/family`, `multi_scale_coverage`, `detailed_reject`.
- **Costs 1 credit per tile** — can burn quota fast; lower accuracy than single-plant identify. Probably not relevant for Yvoty's core "photograph one plant" flow.

## 4. Supporting endpoints

- `GET /v2/projects` — list of valid `project` (flora) values for the `{project}` path param.
- `GET /v2/languages` — supported language codes for `lang` param, e.g. `["en","fr","es","pt","de","it","ar","cs", ...]`.
- `GET /v2/_status` — health check, `{ "status": "ok" }`.
- `GET /v2/subscription` — account + contract + billing + security-settings info for the API key.
- `GET /v2/quota` — daily allowance per request category.
- `GET /v2/quota/daily` — today's usage/remaining per category.
- `GET /v2/quota/history` — historical daily usage (contractualized/paid accounts only).

## 5. Quotas & rate limiting

- Quotas are **per user, per request category, per day**, reset at 00:00:00 UTC.
- Categories group related routes (e.g. all `/v2/identify/*` = `identify` category).
- Rate-limit info comes back as HTTP headers on every response:
  - `RateLimit-Policy`: `q` (allowance), `w` (window seconds, 86400=daily), `pk` (partition key)
  - `RateLimit`: `r` (remaining), `t` (seconds to reset), `pk`
  - `Retry-After` (on 429s): RFC 7231 timestamp of next reset
- Exceeding quota → `HTTP 429` with `Retry-After` header.
- Since 2026-02-13: on the **free plan**, even error responses consume 1 credit — so client-side validation (file type/size, organ count) before calling the API matters for a hobby project.

## 6. Pricing

- **Free plan**: exists (no numbers given in docs beyond the above), fine for prototyping Yvoty.
- **Pro plan**: for high volume — 200,000 requests/year, €1,000 upfront (due 30 days after signing) + tiered overage billing at contract end (€0.005/id ≤3M, down to €0.002/id >300M). Contract signed via DocuSign, wire transfer billing. Not relevant unless Yvoty scales significantly.

## 7. Image guidelines (for capture UX)

From the FAQ:
- Prefer POST with images at least **800×800px**; server resizes down to max 1280px on the longest side (never upscales).
- JPEG ~90% quality is the recommended compression target.
- Effectiveness ranking of organ/photo type for identification accuracy: **flower > fruit > leaf > entire plant > bark**. Worth nudging users in the camera UI to prioritize flower/fruit shots when available.
- Up to 5 photos of the *same individual* plant significantly improves accuracy — Yvoty's capture flow should support a multi-shot "one plant, several angles/organs" session rather than one photo = one identification.
- Organ tagging (`leaf`/`flower`/`fruit`/`bark`) can be set manually or left as `auto` for AI detection.

## 8. Reusing Pl@ntNet's own images (if we ever display community reference photos)

- Licensed **CC BY-SA**. Any reuse must credit "Pl@ntNet" + the license + the original contributor's username.
- Suggested caption format: `Photo(s): [Username] / Pl@ntNet, CC BY-SA`.
- This applies to images *returned by* the API (e.g. via `include-related-images`), not to photos the user submits themselves.

## 9. Model / data notes

- Current identification model: **InceptionV3**-based, retrained roughly every 2 months with non-regression testing against private benchmark datasets.
- Taxonomic backbone since Oct 2023: Kew Gardens / TDWG (WCVP) floras — as of the Jan 2026 changelog entry, species coverage is ~77k with a newer WCVP v13 model (per Sept 2025 entry).
- `version` field in identify responses reports which model build served the request — worth logging/storing alongside a user's saved identification in case results are later reproduced/audited.

## 10. Relevant recent changelog items (context for design decisions)

- 2026-03-03: species illustrations optionally returned via `/v2/species` (Pro only).
- 2026-02-13: free-plan error responses now cost 1 credit.
- 2025-12-02: varieties + diseases identification launched.
- 2025-09-23: genus/family breakdown now opt-in via `detailed=true` (previously always included) — if Yvoty ever showed "other possible genus/family" info, must now explicitly request it.
- 2025-08-05: `otherResults` field added; pagination default-enabled on species-listing routes (paging params likely needed for `/v2/species`, `/v2/varieties`, `/v2/diseases` at scale).
- 2025-01-14: `predictedOrgans` added to identify responses — useful for showing users "we detected this photo as a leaf" feedback in the UI.
- 2019: scores moved from `[0,100)` to `[0,1)` — if referencing any older blog posts/examples, scores will look different.

## 11. Implications for Yvoty's design (not from docs — working notes)

- Store `gbif.id` / `powo.id` per saved plant to enable future enrichment (vernacular names, taxonomy pages) without re-calling Pl@ntNet.
- Capture flow: support multi-photo sessions per plant (up to 5), tag organ type per shot (or `auto`), and default `project=all` unless we later scope to a regional flora.
- Track `remainingIdentificationRequests` / quota headers client-side to warn users before they get 429'd, especially since even failed calls burn credits on the free plan — validate image count/size/format locally first.
- Diseases and varieties identification are separate, limited-coverage beta endpoints — nice-to-have "pokedex" extras later, not needed for MVP.
- Survey/tiling endpoint is for plot-level multi-species detection (drone/quadrat use case) — out of scope for a personal single-plant photo pokedex.
- Full machine-readable spec lives behind "Open API" (`/doc/api/openapi`) — that landing page didn't expose a direct spec file/URL; if we need codegen (typed client), have an agent look for a `.json`/`.yaml` OpenAPI file on the my-api.plantnet.org host or ask Pl@ntNet support.
