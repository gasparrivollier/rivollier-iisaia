#!/usr/bin/env python3
"""Quick draft script to smoke-test the Pl@ntNet identify endpoint.

Usage:
    python scripts/test_plantnet.py path/to/photo.jpg [more.jpg ...] [--save-raw out.json] [--lang es]

Reads PLANTNET_API_KEY from .env at the repo root.
"""

import json
import mimetypes
import sys
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
API_BASE = "https://my-api.plantnet.org"


def load_api_key() -> str:
    env_path = REPO_ROOT / ".env"
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if line.startswith("PLANTNET_API_KEY="):
            return line.split("=", 1)[1].strip()
    raise RuntimeError(f"PLANTNET_API_KEY not found in {env_path}")


def identify(image_paths: list[str], api_key: str, lang: str | None = None) -> dict:
    url = f"{API_BASE}/v2/identify/all"
    params = {"api-key": api_key}
    if lang:
        params["lang"] = lang
    files = [
        (
            "images",
            (
                Path(p).name,
                open(p, "rb"),
                mimetypes.guess_type(p)[0] or "application/octet-stream",
            ),
        )
        for p in image_paths
    ]
    try:
        response = requests.post(url, params=params, files=files, timeout=30)
    finally:
        for _, (_, fh, _) in files:
            fh.close()
    response.raise_for_status()
    return response.json()


def main() -> None:
    args = sys.argv[1:]
    save_raw_path = None
    if "--save-raw" in args:
        idx = args.index("--save-raw")
        save_raw_path = args[idx + 1]
        del args[idx : idx + 2]

    lang = None
    if "--lang" in args:
        idx = args.index("--lang")
        lang = args[idx + 1]
        del args[idx : idx + 2]

    if not args:
        print(f"Usage: {sys.argv[0]} path/to/photo.jpg [more.jpg ...] [--save-raw out.json] [--lang es]")
        sys.exit(1)

    api_key = load_api_key()
    data = identify(args, api_key, lang)

    if save_raw_path:
        Path(save_raw_path).write_text(json.dumps(data, indent=2, ensure_ascii=False))
        print(f"Saved raw response to {save_raw_path}")

    print(f"Best match: {data.get('bestMatch')}")
    for result in data.get("results", [])[:5]:
        species = result["species"]
        print(
            f"  {result['score']:.2%}  {species['scientificNameWithoutAuthor']}"
            f"  (common: {', '.join(species.get('commonNames', [])) or 'n/a'})"
        )
    print(f"Remaining identification requests today: {data.get('remainingIdentificationRequests')}")


if __name__ == "__main__":
    main()
