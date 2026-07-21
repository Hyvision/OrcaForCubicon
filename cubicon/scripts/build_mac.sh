#!/usr/bin/env bash
# build_mac.sh — one-command OrcaForCubicon macOS build + package.
# Assumes the repo is already git-updated. Produces OrcaForCubicon.app and (by default) a DMG
# with an auto version + timestamp filename:  dist/OrcaForCubicon_<ver>_macOS_<arch>_<yyyymmdd_HHMMSS>.dmg
#
#   (no args)     apply overlay -> build app -> package DMG   (deps auto-built only if missing)
#   -a <arch>     arm64 (default on Apple Silicon) | x86_64 | universal
#   -c            clean: wipe build/<arch> first for a fresh app build
#   -D            force-rebuild dependencies (otherwise reused if deps/build/<arch>/OrcaSlicer_dep exists)
#   -P            skip packaging (stop after the .app build)
#   -t <ver>      macOS deployment target (default 11.3)
#
# Notes:
#  * Committed src/ + resources/ are upstream-pristine; Cubicon changes live only in the overlay
#    (cubicon/patches + cubicon/resources). This script resets those trees to HEAD and re-applies
#    the overlay every run, so it always builds the committed SSOT deterministically (uncommitted
#    hand-edits under src/ or resources/ are discarded — commit them first).
set -euo pipefail
SECONDS=0

ARCH=""; CLEAN=0; FORCE_DEPS=0; SKIP_PKG=0; DEPLOY_TGT="11.3"
while getopts ":a:cDPt:h" opt; do
  case "$opt" in
    a) ARCH="$OPTARG" ;;
    c) CLEAN=1 ;;
    D) FORCE_DEPS=1 ;;
    P) SKIP_PKG=1 ;;
    t) DEPLOY_TGT="$OPTARG" ;;
    h) echo "Usage: build_mac.sh [-a arm64|x86_64|universal] [-c clean] [-D force deps] [-P skip package] [-t 11.3]"; exit 0 ;;
    *) ;;
  esac
done
[ -z "$ARCH" ] && ARCH="$(uname -m)"   # arm64 on Apple Silicon, x86_64 on Intel

REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"

echo "== [1/5] Applying Cubicon overlay (reset to pristine + apply patches/resources) =="
git checkout -- src resources 2>/dev/null || true   # discard prior overlay application
bash "$REPO/cubicon/scripts/apply_overlay.sh"

DEPS_MARK="deps/build/$ARCH/OrcaSlicer_dep"
if [ "$FORCE_DEPS" -eq 1 ] || [ ! -d "$DEPS_MARK" ]; then
  echo "== [2/5] Building dependencies ($ARCH) =="
  ./build_release_macos.sh -d -a "$ARCH" -t "$DEPLOY_TGT"
else
  echo "== [2/5] Reusing existing dependencies ($DEPS_MARK) — pass -D to rebuild =="
fi

if [ "$CLEAN" -eq 1 ] && [ -d "build/$ARCH" ]; then
  echo "== [3/5] Clean: removing build/$ARCH =="
  rm -rf "build/$ARCH"
else
  echo "== [3/5] Incremental build (pass -c for a fresh build/$ARCH) =="
fi

echo "== [4/5] Building slicer ($ARCH) =="
./build_release_macos.sh -s -a "$ARCH" -t "$DEPLOY_TGT"

APP="build/$ARCH/OrcaSlicer/OrcaSlicer.app"   # bundle name is hardcoded upstream; rebranded in package_mac.sh
[ -d "$APP" ] || { echo "!! build finished but $APP not found — check the log above." >&2; exit 1; }

if [ "$SKIP_PKG" -eq 1 ]; then
  echo "== [5/5] Skipped packaging (-P) — app at $APP =="
else
  echo "== [5/5] Packaging DMG =="
  bash "$REPO/cubicon/scripts/package_mac.sh" -a "$ARCH"
fi

elapsed=$SECONDS
printf "== build_mac.sh complete in %dh %dm %ds ==\n" $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60))
