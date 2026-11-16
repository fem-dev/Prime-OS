#!/usr/bin/env python3
"""Write os-iso-parts.json next to the parts uploaded to a release.

The setup wizard reads this manifest, downloads every listed part and joins
them, so an image larger than GitHub's 2 GiB asset limit still reaches users
without any external hosting.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys


def sha256_of(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: write_parts_manifest.py <upload-dir> <total-size> <whole-file-sha256>",
              file=sys.stderr)
        return 2
    folder = pathlib.Path(sys.argv[1])
    total = int(sys.argv[2])
    whole = sys.argv[3].strip().lower()
    paths = sorted(folder.glob("os.iso.part*"))
    if not paths:
        print("no os.iso.part* files found", file=sys.stderr)
        return 1
    parts = [
        {"name": path.name, "size": path.stat().st_size, "sha256": sha256_of(path)}
        for path in paths
    ]
    joined = sum(part["size"] for part in parts)
    if joined != total:
        print(f"parts total {joined} bytes but the image is {total} bytes", file=sys.stderr)
        return 1
    manifest = {"format": 1, "name": "os.iso", "size": total, "sha256": whole, "parts": parts}
    (folder / "os-iso-parts.json").write_text(json.dumps(manifest, indent=2) + "\n",
                                              encoding="utf-8")
    print(f"wrote os-iso-parts.json with {len(parts)} parts covering {joined} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
