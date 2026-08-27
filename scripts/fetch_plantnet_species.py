#!/usr/bin/env python3
"""Paginate through the full Pl@ntNet species catalog and dump it to CSV.

Usage:
    python scripts/fetch_plantnet_species.py [out.csv]

Reads PLANTNET_API_KEY from .env at the repo root. Uses GET /v2/species with
page/pageSize params (pageSize=500 confirmed to work), stopping once a page
comes back empty.
"""

import csv
import sys
import time
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
API_BASE = "https://my-api.plantnet.org"
PAGE_SIZE = 500

FIELDS = [
    "id",
    "scientificNameWithoutAuthor",
    "scientificNameAuthorship",
    "genus",
    "commonNames",
    "gbifId",
    "powoId",
    "iucnCategory",
]


def load_api_key() -> str:
    env_path = REPO_ROOT / ".env"
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if line.startswith("PLANTNET_API_KEY="):
            return line.split("=", 1)[1].strip()
    raise RuntimeError(f"PLANTNET_API_KEY not found in {env_path}")


def flatten(species: dict) -> dict:
    genus = species.get("genus")
    if isinstance(genus, dict):
        genus = genus.get("scientificNameWithoutAuthor") or genus.get("scientificName")
    return {
        "id": species.get("id"),
        "scientificNameWithoutAuthor": species.get("scientificNameWithoutAuthor"),
        "scientificNameAuthorship": species.get("scientificNameAuthorship"),
        "genus": genus,
        "commonNames": "; ".join(species.get("commonNames") or []),
        "gbifId": species.get("gbifId"),
        "powoId": species.get("powoId"),
        "iucnCategory": species.get("iucnCategory"),
    }


def main() -> None:
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO_ROOT / "docs" / "examples" / "plantnet-species.csv"
    api_key = load_api_key()
    url = f"{API_BASE}/v2/species"

    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()

        page = 1
        total = 0
        while True:
            response = requests.get(
                url,
                params={"api-key": api_key, "page": page, "pageSize": PAGE_SIZE},
                timeout=60,
            )
            response.raise_for_status()
            batch = response.json()
            if not batch:
                break

            for species in batch:
                writer.writerow(flatten(species))
            f.flush()

            total += len(batch)
            print(f"page {page}: +{len(batch)} (total {total})")

            if len(batch) < PAGE_SIZE:
                break

            page += 1
            time.sleep(0.2)

    print(f"Done. Saved {total} species to {out_path}")


if __name__ == "__main__":
    main()
