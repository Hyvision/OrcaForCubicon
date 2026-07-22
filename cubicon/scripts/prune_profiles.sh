#!/usr/bin/env bash
# prune_profiles.sh — keep ONLY Cubicon printer profiles in resources/profiles at build time.
# OrcaForCubicon ships as a Cubicon-only slicer, so every other vendor's profiles are removed so the
# first-run wizard and the printer list show only Cubicon. The committed tree stays full-upstream;
# this prune runs from apply_overlay after the overlay copy.
#
# Kept:
#   Cubicon             - the Cubicon printers/filaments/processes
#   OrcaFilamentLibrary - code-required shared filament library (PresetBundle::ORCA_FILAMENT_LIBRARY),
#                         has no printers so it never appears as a printer vendor
#   blacklist           - infrastructure (blacklist.json), no dir
set -euo pipefail
REPO="$(git rev-parse --show-toplevel)"
DIR="$REPO/resources/profiles"
[ -d "$DIR" ] || { echo "  (no resources/profiles yet)"; exit 0; }

KEEP=" Cubicon OrcaFilamentLibrary blacklist "
cd "$DIR"

removed=0
# 1) vendor index json + its same-named dir
for f in *.json; do
  [ -e "$f" ] || continue
  name="${f%.json}"
  case "$KEEP" in *" $name "*) continue;; esac
  rm -f "$f"
  [ -d "$name" ] && rm -rf "$name"
  removed=$((removed+1))
done
# 2) any leftover vendor dirs without a matching json
for d in */; do
  [ -d "$d" ] || continue
  name="${d%/}"
  case "$KEEP" in *" $name "*) continue;; esac
  rm -rf "$name"
done

echo "  pruned $removed non-Cubicon vendor profile set(s); kept: Cubicon, OrcaFilamentLibrary, blacklist"
