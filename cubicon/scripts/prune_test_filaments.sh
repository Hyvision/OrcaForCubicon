#!/usr/bin/env bash
# prune_test_filaments.sh — RELEASE builds only. Mirrors cubicon/scripts/prune_test_filaments.ps1.
# Removes "test-only" filaments (listed in cubicon/version/test_only_filaments.txt) from the
# STAGED build tree (resources/profiles/Cubicon) so unverified filaments ship in TEST builds but
# not in RELEASE builds. This edits the generated resources/ copy (regenerated from the overlay on
# every build) — it never touches the overlay SSOT under cubicon/resources/.
#
# Matching: a manifest line matches a filament whose name == the line, or starts with "<line> @".
# It removes both the filament JSON files and the matching entries from Cubicon.json filament_list.
set -euo pipefail
REPO="$(git rev-parse --show-toplevel)"
MANIFEST="$REPO/cubicon/version/test_only_filaments.txt"
FIL_DIR="$REPO/resources/profiles/Cubicon/filament"
JSON_PATH="$REPO/resources/profiles/Cubicon.json"

if [ ! -f "$MANIFEST" ]; then
  echo "  (no test_only_filaments manifest; nothing to prune)"
  exit 0
fi

PREFIXES=()
while IFS= read -r line; do
  line="${line%%$'\r'}"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  PREFIXES+=("$line")
done < "$MANIFEST"

if [ "${#PREFIXES[@]}" -eq 0 ]; then
  echo "  (manifest is empty; nothing to prune)"
  exit 0
fi

is_test_only() {
  local name="$1" p
  for p in "${PREFIXES[@]}"; do
    [ "$name" = "$p" ] && return 0
    case "$name" in "$p @"*) return 0 ;; esac
  done
  return 1
}

# 1) delete matching filament JSON files
removed_files=0
if [ -d "$FIL_DIR" ]; then
  while IFS= read -r -d '' f; do
    stem="$(basename "$f" .json)"
    if is_test_only "$stem"; then
      rm -f "$f"
      removed_files=$((removed_files + 1))
    fi
  done < <(find "$FIL_DIR" -maxdepth 1 -name '*.json' -print0)
fi

# 2) remove matching entries from Cubicon.json filament_list
removed_entries=0
if [ -f "$JSON_PATH" ]; then
  before_count="$(jq '(.filament_list // []) | length' "$JSON_PATH")"
  tmp="$(mktemp)"
  # NOTE: --args routes ALL trailing positional args into $ARGS.positional (none are treated as
  # input files), so the JSON input must come via stdin redirect, not as a positional filename.
  jq --args \
    'if has("filament_list") then
       .filament_list |= map(select(
         (.name as $n |
           ($ARGS.positional | any(. as $p | $n == $p or ($n | startswith($p + " @")))) | not
         )
       ))
     else . end' \
    "${PREFIXES[@]}" < "$JSON_PATH" > "$tmp"
  after_count="$(jq '(.filament_list // []) | length' "$tmp")"
  removed_entries=$((before_count - after_count))
  mv "$tmp" "$JSON_PATH"
fi

joined="$(IFS=,; echo "${PREFIXES[*]}")"
echo "  pruned ${removed_files} test-only filament file(s), ${removed_entries} filament_list entr(y/ies): ${joined}"
