#!/usr/bin/env bash
# build_mac.sh — full one-shot OrcaForCubicon macOS pipeline:
#   deps (if needed) -> apply overlay -> build slicer (.app)
# Mirrors cubicon/scripts/build_win.ps1. Run from anywhere inside the repo.
#
#   -a <arch>     arm64 (default on Apple Silicon) | x86_64 | universal
#   -s            skip the deps build (reuse deps/build/<arch>/OrcaSlicer_dep)
#   -t <ver>      macOS deployment target (default 11.3)
#
# Packaging (rename to OrcaForCubicon.app + DMG) is a separate step: package_mac.sh
set -euo pipefail
SECONDS=0

ARCH=""
SKIP_DEPS=0
DEPLOY_TGT="11.3"
while getopts ":a:st:h" opt; do
  case "$opt" in
    a) ARCH="$OPTARG" ;;
    s) SKIP_DEPS=1 ;;
    t) DEPLOY_TGT="$OPTARG" ;;
    h) echo "Usage: build_mac.sh [-a arm64|x86_64|universal] [-s skip deps] [-t 11.3]"; exit 0 ;;
    *) ;;
  esac
done
[ -z "$ARCH" ] && ARCH="$(uname -m)"   # arm64 on Apple Silicon, x86_64 on Intel

REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"

echo "== [1] Applying Cubicon overlay =="
# NOTE: overlay must be applied on a PRISTINE tree (committed src/ is upstream-pristine;
# Cubicon changes live only as cubicon/patches/*.patch + cubicon/resources/*).
# If patches fail to apply, the tree already has them applied (or upstream drifted) —
# run `git status` and reset src/ before retrying.
bash "$REPO/cubicon/scripts/apply_overlay.sh"

if [ "$SKIP_DEPS" -ne 1 ]; then
  echo "== [2] Building dependencies ($ARCH) =="
  ./build_release_macos.sh -d -a "$ARCH" -t "$DEPLOY_TGT"
fi

echo "== [3] Building slicer ($ARCH) =="
./build_release_macos.sh -s -a "$ARCH" -t "$DEPLOY_TGT"

APP="build/$ARCH/OrcaSlicer/OrcaSlicer.app"   # bundle name is hardcoded upstream; renamed in package_mac.sh
echo
if [ -d "$APP" ]; then
  echo "== build_mac.sh complete: $APP =="
else
  echo "!! build finished but $APP not found — check the build log above." >&2
  exit 1
fi
elapsed=$SECONDS
printf "Elapsed: %dh %dm %ds\n" $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60))
