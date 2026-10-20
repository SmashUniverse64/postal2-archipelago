#!/usr/bin/env python3
"""Stage GitHub Release files and a Steam Workshop upload folder.

Run from the Archipelago repo root after compiling Archipelago.u (make.bat).
Packs postal2.apworld, then copies:

  dist/<world_version>/   postal2.apworld, postal2.yaml, Archipelago.u, Archipelago.int
  workshop/staging/       Archipelago.u, Archipelago.int, preview.png
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APWORLD_DIR = ROOT / "apworld"
SYSTEM = ROOT.parent / "System"
INT_SRC = ROOT / "Archipelago.int"
PREVIEW = ROOT / "workshop" / "preview.png"
MANIFEST = APWORLD_DIR / "postal2" / "archipelago.json"


def main() -> None:
    version = json.loads(MANIFEST.read_text(encoding="utf-8"))["world_version"]
    u_src = SYSTEM / "Archipelago.u"
    if not u_src.is_file():
        raise SystemExit(f"Missing {u_src}. Run make.bat from this folder first.")
    if not INT_SRC.is_file():
        raise SystemExit(f"Missing {INT_SRC}")
    if not PREVIEW.is_file():
        raise SystemExit(f"Missing {PREVIEW}")

    subprocess.check_call([sys.executable, str(APWORLD_DIR / "pack_apworld.py")], cwd=APWORLD_DIR)

    dist = ROOT / "dist" / version
    dist.mkdir(parents=True, exist_ok=True)
    shutil.copy2(APWORLD_DIR / "postal2.apworld", dist / "postal2.apworld")
    shutil.copy2(APWORLD_DIR / "postal2.yaml", dist / "postal2.yaml")
    shutil.copy2(u_src, dist / "Archipelago.u")
    shutil.copy2(INT_SRC, dist / "Archipelago.int")

    staging = ROOT / "workshop" / "staging"
    staging.mkdir(parents=True, exist_ok=True)
    shutil.copy2(u_src, staging / "Archipelago.u")
    shutil.copy2(INT_SRC, staging / "Archipelago.int")
    shutil.copy2(PREVIEW, staging / "preview.png")

    print(f"GitHub Release files: {dist}")
    print(f"Workshop staging:     {staging}")
    print(f"Version:              {version}")


if __name__ == "__main__":
    main()
