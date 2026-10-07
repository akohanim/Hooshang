#!/usr/bin/env python3
"""Run Godot regression scenes sequentially and save one log per scene.

Use --fast for an initial physics sweep; rerun timing failures without it.
Rendering checks are excluded from headless mode and listed in the report.
"""
import argparse
import json
import shutil
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="*", help="Test stems (e.g. smoke save); default: all")
    parser.add_argument("--godot", default=shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--timeout", type=float, default=60)
    parser.add_argument("--fast", action="store_true")
    parser.add_argument("--output", type=Path, default=ROOT / "output/regressions")
    args = parser.parse_args()
    scenes = sorted((ROOT / "tests").glob("*test.tscn"))
    if args.tests:
        names = {name.removesuffix(".tscn").removesuffix("_test") for name in args.tests}
        available = {path.stem.removesuffix("_test") for path in scenes}
        if names - available:
            parser.error("Unknown tests: " + ", ".join(sorted(names - available)))
        scenes = [p for p in scenes if p.stem.removesuffix("_test") in names]
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for scene in scenes:
        source = scene.with_suffix(".gd").read_text()
        if "RenderingServer.frame_post_draw" in source or "get_texture().get_image()" in source:
            results.append({"test": scene.stem, "status": "requires_rendering"})
            continue
        cmd = [args.godot, "--headless", "--path", str(ROOT)]
        if args.fast:
            cmd += ["--fixed-fps", "60"]
        cmd += ["res://" + scene.relative_to(ROOT).as_posix()]
        started = time.monotonic()
        log_path = args.output / (scene.stem + ".log")
        with log_path.open("w") as log:
            try:
                run = subprocess.run(cmd, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
                status = "passed" if run.returncode == 0 else "failed"
            except subprocess.TimeoutExpired:
                status = "timeout"
        # A parse failure can terminate with zero on some Godot versions.
        if status == "passed" and "SCRIPT ERROR:" in log_path.read_text():
            status = "failed"
        results.append({"test": scene.stem, "status": status, "seconds": round(time.monotonic() - started, 2)})
        (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
        print(f"{scene.stem}: {status}", flush=True)
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return int(any(r["status"] in ("failed", "timeout") for r in results))


if __name__ == "__main__":
    raise SystemExit(main())
