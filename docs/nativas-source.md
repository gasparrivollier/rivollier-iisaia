# nativas.lanacion.com.ar — data source reference

Reference for the native-species catalog scraped by `scripts/fetch_nativas_species.py`
into `docs/examples/nativas-species.csv` / `nativas-species-detail.jsonl`. Fills the
data-curation gap noted in `docs/architecture.md`'s "Region map addition" section —
Pl@ntNet has no native-species-by-region endpoint, this site does.

Site: [nativas.lanacion.com.ar](https://nativas.lanacion.com.ar), a joint project of
La Nación (Proyecto Naturaleza), Aves Argentinas, and Revista Jardín. `robots.txt`
allows all (`Disallow:` empty). Catalog is ~265 native Argentine species.

## How the site is structured

Next.js SSR. Every page embeds its full page JSON in
`<script id="__NEXT_DATA__" type="application/json">…</script>`. **Always parse that
script tag**, not `/_next/image` or any other endpoint on the page:

- `/_next/data/<buildId>/...` looks like it should return the same JSON directly, but
  returns 404 (confirmed) — and `buildId` changes on every site deploy anyway, so it
  wouldn't be stable even if it worked.
- No other API endpoint is exposed for this data on these pages.

### List page: `GET /plantas`

`props.pageProps.allPlantasData` — an array of all ~265 species, each:

```json
{
  "id": 26,
  "nombre": "Canna glauca",
  "nombre_popular": "Achira amarilla",
  "ecoregiones": ["Esteros del Iberá", "Selva Paranaense", "Delta e Islas del Paraná", "Chaco Húmedo"],
  "portada": "images/Canna_glauca-Achira_amarilla/Castro_C-Canna_glauca-fl.JPG",
  "filtros": ["aves", "picaflores", "polinizadores", "..."],
  "busqueda": ["Canna glauca", "Achira amarilla", "Achira", ""]
}
```

`props.pageProps._defEco` is the full canonical list of ~20 ecoregion codes the site's
filter UI knows about (underscored, includes a couple not present in any species'
`ecoregiones`, e.g. `Altos_Andes`, `Islas_del_Atlántico_Sur`, `Mar_Argentino`).

No pagination — all species render in one response.

### Detail page: `GET /plantas/planta/{slug}`

`props.pageProps.plantaData` — full record for one species: `familia_nombre`,
`forma_vida_nombre`/`sub_forma_vida_nombre` (growth habit), `destaca` (long-form
description), `altura_maxima`/`diametro_maximo`, cultivation (`sol`/`media_sombra`/
`sombra`, `riego`, `maceta`, `duracion`, `follaje`, `propagacion`), a
per-season boolean calendar (`flo_primavera`/`flo_verano`/`flo_otono`/`flo_invierno`,
same pattern for `fru_*` and `follaje_*`), fauna (`aves`, `picaflores`, `mariposas`,
`mariposas_orugas`, `polinizadores`, `texto_fauna`, `link_fauna`), habitat
(`ambiente_bosque_seco`/`ambiente_pastizal`/`ambiente_lagunas_banados`/
`ambiente_bosque_humedo`), `ecoregiones` (same list as the list page), and `fotos`:
an array of `{image, credito, orden, comentario}` — every photo carries an
individual attribution (`credito`) that should be preserved wherever these images
are used or displayed.

**Slug rule** — `nombre.replace(' ', '_')`, literal, no other normalization.
Verified edge cases:
- Accented characters pass through untouched: `"Tillandsia aeränthos"` →
  `/plantas/planta/Tillandsia_aeränthos` (200).
- A double space in the source name becomes a double underscore — do **not**
  collapse it: `"Acanthosyris  spinescens"` → `/plantas/planta/Acanthosyris__spinescens`
  (200); the collapsed form `Acanthosyris_spinescens` 500s.

### Images

`image`/`portada` paths are relative to `https://especialess3.lanacion.com.ar/plantas_nativas/media/`
— La Nación's own CDN, fetchable directly (no `_next/image` proxy needed).

### Ecoregions found in the data (17, of the ~20 the site's filter UI defines)

Bosques Patagónicos, Bosques Patagónicos Sur, Campos y Malezales, Chaco Húmedo,
Chaco Seco, Delta e Islas del Paraná, Espinal, Espinal Norte, Espinal Sur, Estepa
Patagónica, Esteros del Iberá, Monte de Llanuras y Mesetas, Monte de Sierras y
Bolsones, Pampeana, Puna, Selva Paranaense, Yungas.

This is Argentina's standard ecological-region classification — **not** the same
axis as the 24 political provinces `client/lib/data/models/region.dart` and
`client/assets/data/ar-lowpoly.geojson` use. A plant's `ecoregiones` list does not
map 1:1 to provinces (e.g. a Yungas-only species spans parts of Jujuy, Salta and
Tucumán, not their entirety). Decision recorded in `docs/architecture.md`: store
ecoregión as scraped, and derive province-level "present" via a separate static
ecoregion→province(s) mapping table for the existing map screen, rather than
discarding the ecoregion or replacing the province-based model.

Not found: any locality→ecoregion resolution data backing the site's "Ingresá una
localidad argentina" search box — that feature evidently calls another
undisclosed endpoint, not needed for this scrape.

## Regenerating the dataset

```
python scripts/fetch_nativas_species.py list      # -> docs/examples/nativas-species.csv (~265 rows, 1 request)
python scripts/fetch_nativas_species.py detail     # -> docs/examples/nativas-species-detail.jsonl (~265 requests, ~1 min)
```

`detail` accepts explicit scientific names as args to fetch/test a subset instead of
the full catalog (reads `nativas-species.csv` for the full list when none given).
Failed detail fetches are logged to stderr and skipped, not fatal to the batch — as
of the last run (2026-09-05), 265/265 succeeded with zero failures.

After fetching detail, `detail` also rewrites `nativas-species.csv` in place, adding
six columns pulled from the detail records (matching the labeled fields the site's
own detail page shows, e.g. "Ambiente:", "Duración:"): `ambiente`, `duracion`,
`tipo_follaje`, `color_floracion`, `perfume`, `propagacion`. `ambiente` is derived
from the four `ambiente_*` booleans on `plantaData` (`ambiente_bosque_seco`,
`ambiente_pastizal`, `ambiente_lagunas_banados`, `ambiente_bosque_humedo`) — a
species can be tagged with more than one, joined `"; "`-separated (66/265 have two,
9/265 have three, 1/265 has all four). `perfume` is rendered `Sí`/`No`. The other
four are the corresponding raw string fields (`duracion`, `follaje`, `color_nombre`,
`propagacion`) with just the first letter capitalized to match the site's display —
these columns are separate from (not a replacement for) the catch-all `filtros`
column, which still carries the site's full raw tag list per species.
