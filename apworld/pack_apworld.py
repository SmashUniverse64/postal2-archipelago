#!/usr/bin/env python3
"""Zip postal2/ into postal2.apworld and copy it into Archipelago custom_worlds."""

from __future__ import annotations

import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PKG = ROOT / "postal2"
OUT = ROOT / "postal2.apworld"
CUSTOM = Path(r"C:\ProgramData\Archipelago\custom_worlds")


def main() -> None:
    if OUT.exists():
        OUT.unlink()
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in PKG.rglob("*"):
            if not path.is_file():
                continue
            if "__pycache__" in path.parts or path.suffix == ".pyc":
                continue
            arc = Path("postal2") / path.relative_to(PKG)
            zf.write(path, arc.as_posix())
    print(f"Wrote {OUT}")
    if CUSTOM.is_dir():
        dest = CUSTOM / "postal2.apworld"
        shutil.copy2(OUT, dest)
        print(f"Installed {dest}")
    else:
        print(f"No Archipelago custom_worlds at {CUSTOM}")


if __name__ == "__main__":
    main()
