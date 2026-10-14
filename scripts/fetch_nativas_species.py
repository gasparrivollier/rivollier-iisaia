#!/usr/bin/env python3
"""Scrape the native-species catalog from nativas.lanacion.com.ar.

Data source for `region_species`/ecoregion curation (see docs/architecture.md's
"Region map addition" and docs/nativas-source.md for the site's data shape).

Two phases, run independently:

    python scripts/fetch_nativas_species.py list             # ~1 request
    python scripts/fetch_nativas_species.py detail [slugs...] # ~265 requests, ~1 min

`detail` with no arguments reads the species list CSV (phase 1's output) and
fetches every one of them; pass explicit scientific names to fetch a subset
(useful for testing edge-case slugs before running the full batch).

The site is server-rendered Next.js: every page embeds the full page JSON in
a `<script id="__NEXT_DATA__">` tag. There is no usable `/_next/data/<buildId>/...`
JSON endpoint (confirmed 404, and buildId changes on every site deploy anyway) —
always parse `__NEXT_DATA__` out of the HTML instead.
"""

import csv
import json
import re
import sys
import time
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
BASE_URL = "https://nativas.lanacion.com.ar"
IMAGE_BASE = "https://especialess3.lanacion.com.ar/plantas_nativas/media/"
LIST_CSV = REPO_ROOT / "docs" / "examples" / "nativas-species.csv"
DETAIL_JSONL = REPO_ROOT / "docs" / "examples" / "nativas-species-detail.jsonl"
HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; yvoty-coursework-scraper/1.0)"}

NEXT_DATA_RE = re.compile(
    r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', re.S
)

# ambiente_* is a set of independent booleans on plantaData (a species can be
# tagged with more than one, e.g. both "Pastizal" and "Bosque húmedo") — the
# site's own detail page just lists them comma/period-joined under "Ambiente:".
AMBIENTE_LABELS = {
    "ambiente_bosque_seco": "Bosque seco",
    "ambiente_pastizal": "Pastizal",
    "ambiente_lagunas_banados": "Lagunas y bañados",
    "ambiente_bosque_humedo": "Bosque húmedo",
}

DETAIL_COLUMNS = [
    "ambiente",
    "duracion",
    "tipo_follaje",
    "color_floracion",
    "perfume",
    "propagacion",
]


def _cap(s: str | None) -> str:
    return s[:1].upper() + s[1:] if s else ""


def detail_columns_for(planta: dict) -> dict:
    ambiente = "; ".join(label for key, label in AMBIENTE_LABELS.items() if planta.get(key))
    return {
        "ambiente": ambiente,
        "duracion": _cap(planta.get("duracion")),
        "tipo_follaje": _cap(planta.get("follaje")),
        "color_floracion": _cap(planta.get("color_nombre")),
        "perfume": "Sí" if planta.get("perfume") else "No",
        "propagacion": _cap(planta.get("propagacion")),
    }


def fetch_next_data(url: str) -> dict:
    resp = requests.get(url, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    match = NEXT_DATA_RE.search(resp.text)
    if not match:
        raise RuntimeError(f"__NEXT_DATA__ not found in {url}")
    return json.loads(match.group(1))


def slug_for(nombre_cientifico: str) -> str:
    # Verified rule: literal space->underscore, no further normalization.
    # Accents pass through untouched; a double space becomes a double
    # underscore (collapsing it to a single one 500s on the real site).
    return nombre_cientifico.replace(" ", "_")


def fetch_list() -> list[dict]:
    data = fetch_next_data(f"{BASE_URL}/plantas")
    return data["props"]["pageProps"]["allPlantasData"]


LIST_COLUMNS = [
    "id",
    "nombre_cientifico",
    "nombre_popular",
    "ecoregiones",
    "portada_url",
    "filtros",
    *DETAIL_COLUMNS,
]


def write_list_csv(rows: list[dict]) -> None:
    # DETAIL_COLUMNS (ambiente/duracion/tipo_follaje/color_floracion/perfume/
    # propagacion) only come from the per-species detail page, not this list
    # endpoint — left blank here and filled in by enrich_list_csv_with_detail
    # once `detail` has been run.
    LIST_CSV.parent.mkdir(parents=True, exist_ok=True)
    with LIST_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=LIST_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "id": row.get("id"),
                    "nombre_cientifico": row.get("nombre"),
                    "nombre_popular": row.get("nombre_popular"),
                    "ecoregiones": ";".join(row.get("ecoregiones") or []),
                    "portada_url": IMAGE_BASE + row["portada"] if row.get("portada") else "",
                    "filtros": ";".join(t for t in (row.get("filtros") or []) if t),
                }
            )
    print(f"Wrote {len(rows)} rows to {LIST_CSV}")


def enrich_list_csv_with_detail(detail_by_name: dict[str, dict]) -> None:
    with LIST_CSV.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    updated = 0
    for row in rows:
        planta = detail_by_name.get(row["nombre_cientifico"])
        if planta is None:
            continue
        row.update(detail_columns_for(planta))
        updated += 1

    with LIST_CSV.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=LIST_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Enriched {updated}/{len(rows)} rows in {LIST_CSV} with detail columns")


def fetch_detail(nombre_cientifico: str) -> dict:
    slug = slug_for(nombre_cientifico)
    data = fetch_next_data(f"{BASE_URL}/plantas/planta/{slug}")
    return data["props"]["pageProps"]["plantaData"]


def load_names_from_list_csv() -> list[str]:
    with LIST_CSV.open(encoding="utf-8") as f:
        return [row["nombre_cientifico"] for row in csv.DictReader(f)]


def run_list() -> None:
    rows = fetch_list()
    write_list_csv(rows)


def run_detail(names: list[str]) -> None:
    if not names:
        names = load_names_from_list_csv()

    detail_by_name: dict[str, dict] = {}
    with DETAIL_JSONL.open("w", encoding="utf-8") as f:
        ok = 0
        for i, nombre in enumerate(names, start=1):
            try:
                planta = fetch_detail(nombre)
            except requests.HTTPError as exc:
                print(f"[{i}/{len(names)}] FAILED {nombre!r}: {exc}", file=sys.stderr)
                continue
            for foto in planta.get("fotos") or []:
                if foto.get("image"):
                    foto["image_url"] = IMAGE_BASE + foto["image"]
            f.write(json.dumps(planta, ensure_ascii=False) + "\n")
            detail_by_name[nombre] = planta
            ok += 1
            print(f"[{i}/{len(names)}] OK {nombre!r}")
            time.sleep(0.2)

    print(f"Done. Saved {ok}/{len(names)} detail records to {DETAIL_JSONL}")
    enrich_list_csv_with_detail(detail_by_name)


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] not in ("list", "detail"):
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == "list":
        run_list()
    else:
        run_detail(sys.argv[2:])


if __name__ == "__main__":
    main()
