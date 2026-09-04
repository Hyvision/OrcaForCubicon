#!/usr/bin/env python3
"""Verify that the build-volume guard parameters reach the generated G-code.

Slices one test model once per machine with the CLI and checks that the first
START_PRINT line carries REQ_X / REQ_Y / REQ_Z matching that machine's build
volume.  See cubicon/doc/build-volume-guard.md.

    python cubicon/scripts/verify_build_volume_guard.py --exe build/OrcaSlicer/OrcaForCubicon.exe

The CLI does not resolve "inherits", so the presets are flattened into
temporary self-contained JSONs first.
"""

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

# machine preset -> (REQ_X, REQ_Y, REQ_Z) expected in the generated G-code
MACHINES = {
    "Cubicon xCeler-Mini 0.4 nozzle": (150, 150, 150),
    "Cubicon xCeler-I 0.4 nozzle":    (250, 250, 290),
    "Cubicon xCeler-Plus 0.4 nozzle": (310, 310, 310),
    "Cubicon xCeler-Plus CoreXY 0.4 nozzle": (310, 310, 310),
}

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROFILES = os.path.join(REPO, "cubicon", "resources", "profiles", "Cubicon")
MODEL = os.path.join(REPO, "tests", "data", "test_stl", "ASCII", "20mmbox-LF.stl")

# keys that describe the preset file itself rather than a config value
DROP = {"instantiation", "inherits", "setting_id", "version", "is_custom_defined"}


def load_index():
    index = {}
    for path in glob.glob(os.path.join(PROFILES, "*", "*.json")):
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        index[d.get("name") or os.path.splitext(os.path.basename(path))[0]] = d
    return index


def flatten(index, name):
    d = index[name]
    merged = flatten(index, d["inherits"]) if d.get("inherits") else {}
    merged.update(d)
    return merged


def emit(index, name, path):
    cfg = {k: v for k, v in flatten(index, name).items() if k not in DROP}
    cfg["name"] = name
    cfg["from"] = "system"          # the CLI rejects presets without a source
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)


def start_print_line(gcode):
    with open(gcode, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("START_PRINT"):
                return line.strip()
    return ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", required=True, help="OrcaForCubicon executable (packaged build directory)")
    ap.add_argument("--keep", action="store_true", help="keep the temporary working directory")
    args = ap.parse_args()

    exe = os.path.abspath(args.exe)
    if not os.path.exists(exe):
        sys.exit("executable not found: %s" % exe)

    index = load_index()
    work = tempfile.mkdtemp(prefix="bvguard_")
    failures = []
    try:
        for machine, expected in MACHINES.items():
            tag = machine.replace(" ", "_")
            m = os.path.join(work, tag + "_machine.json")
            p = os.path.join(work, tag + "_process.json")
            out = os.path.join(work, tag + "_out")
            os.makedirs(out, exist_ok=True)
            emit(index, machine, m)
            emit(index, "cubicon default @" + machine, p)

            rc = subprocess.call(
                [exe, "--datadir", os.path.join(work, "datadir"),
                 "--load-settings", m + ";" + p,
                 "--slice", "0", "--outputdir", out, MODEL],
                cwd=os.path.dirname(exe))
            if rc != 0:
                failures.append("%s: slicing failed (exit %d)" % (machine, rc))
                continue

            line = start_print_line(os.path.join(out, "plate_1.gcode"))
            want = "REQ_X=%d REQ_Y=%d REQ_Z=%d" % expected
            print("%-32s %s" % (machine, line))
            if want not in line:
                failures.append("%s: expected '%s'" % (machine, want))
    finally:
        if not args.keep:
            shutil.rmtree(work, ignore_errors=True)
        else:
            print("working directory: %s" % work)

    if failures:
        print("\nFAIL")
        for f in failures:
            print("  " + f)
        return 1
    print("\nPASS - every machine emits its own build volume")
    return 0


if __name__ == "__main__":
    sys.exit(main())
