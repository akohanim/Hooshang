#!/usr/bin/env python3
"""Export the single-threaded Web preset and zip its root for itch.io."""
import argparse
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", default=shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot")
args = parser.parse_args()
builds = root / "builds"
builds.mkdir(exist_ok=True)
# Export into a clean staging directory so old service workers cannot ship.
with tempfile.TemporaryDirectory(prefix="mobile-web-", dir=builds) as temporary:
    staging = Path(temporary)
    subprocess.run([args.godot, "--headless", "--path", str(root),
                    "--export-release", "Web", str(staging / "index.html")], check=True)
    for required in ("index.html", "index.js", "index.wasm", "index.pck"):
        if not (staging / required).is_file():
            raise RuntimeError(f"Export missing {required}")
    archive = builds / "hooshang-mobile-web.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for file in sorted(staging.iterdir()):
            if file.is_file():
                bundle.write(file, file.name)
    destination = builds / "mobile-web"
    destination.mkdir(exist_ok=True)
    for file in staging.iterdir():
        if file.is_file():
            shutil.copy2(file, destination / file.name)
    with zipfile.ZipFile(archive) as bundle:
        if bundle.testzip() is not None:
            raise RuntimeError("Archive integrity check failed")
    print(f"Upload {archive} ({archive.stat().st_size / 1024**2:.1f} MiB)")
