#!/usr/bin/env python3
"""Exa web search for Prime-OS.

Looks up current pages for a query with ``exa-py``, the official Exa SDK, and
returns every hit together with the highlight sentences that matter for the
query. Handy for hardware notes, driver quirks and gaming reports that are not
in this repository.

The API key is read from the ``EXA_API_KEY`` environment variable; copy
``.env.example`` to ``.env`` and fill it in, or export it in your shell (a
local ``.env`` or ``.env.local`` is read when the variable is not set):

    export EXA_API_KEY="your-key"           # PowerShell: setx EXA_API_KEY "your-key"

    python web_search.py "Hyprland NVIDIA flicker fix"
    python web_search.py "Arch Linux gaming" --num-results 3
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

try:
    from exa_py import Exa
except ImportError as exc:  # pragma: no cover - depends on the host environment
    raise SystemExit(
        "Prime-OS needs the Exa SDK. Install it with: pip install -r requirements.txt"
    ) from exc

API_KEY_ENV = "EXA_API_KEY"
ENV_FILES = (".env", ".env.local")
DEFAULT_RESULTS = 5
MAX_RESULTS = 100


def load_env_files() -> None:
    """Fill unset variables from a local env file; existing values always win."""
    root = Path(__file__).resolve().parent
    for name in ENV_FILES:
        path = root / name
        if not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.removeprefix("export ").strip()
            value = value.strip().strip("\"'")
            if key and value:
                os.environ.setdefault(key, value)


def client() -> Exa:
    """Return an Exa client, or explain which variable is missing."""
    load_env_files()
    if not os.environ.get(API_KEY_ENV, "").strip():
        raise SystemExit(
            f"Set {API_KEY_ENV} in your environment before searching (see .env.example)."
        )
    return Exa()                       # the SDK reads EXA_API_KEY itself


def search_web(query: str, num_results: int = DEFAULT_RESULTS, *, search_type: str = "auto"):
    """Search the web with Exa and return the results, each with page highlights."""
    query = query.strip()
    if not query:
        raise ValueError("A non-empty search query is required")
    limit = max(1, min(int(num_results), MAX_RESULTS))
    response = client().search(
        query,
        type=search_type,
        num_results=limit,
        contents={"highlights": True},
    )
    return response.results


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    num_results = DEFAULT_RESULTS
    if "--num-results" in args:
        index = args.index("--num-results")
        try:
            num_results = int(args[index + 1])
        except (IndexError, ValueError):
            raise SystemExit("--num-results needs a number") from None
        del args[index:index + 2]
    query = " ".join(args).strip()
    if not query:
        raise SystemExit('Usage: python web_search.py "query" [--num-results N]')

    try:
        results = search_web(query, num_results)
    except Exception as exc:           # report API and network failures, never hide them
        print(f"Exa search failed: {exc}", file=sys.stderr)
        return 1

    if not results:
        print("Exa returned no results for this query.")
        return 0
    for number, result in enumerate(results, 1):
        print(f"{number}. {result.title or result.url}")
        print(f"   {result.url}")
        for highlight in result.highlights or []:
            print(f"   - {' '.join(highlight.split())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
