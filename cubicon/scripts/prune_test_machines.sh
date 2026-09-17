#!/usr/bin/env bash
# prune_test_machines.sh — RELEASE builds only. Mirrors cubicon/scripts/prune_test_machines.ps1.
# Removes "test-only" machines (listed in cubicon/version/test_only_machines.txt) from the STAGED
# build tree (resources/profiles/Cubicon) so an unverified printer line ships in TEST builds but not
# in RELEASE builds. This edits the generated resources/ copy (regenerated from the overlay on every
# build) — it never touches the overlay SSOT under cubicon/resources/.
#
# Matching for a manifest line <M> (a printer model name):
#   machine_model  : name == <M>
#   machine        : name == <M>  or  name starts with "<M> "        ("<M> 0.4 nozzle")
#   process/filament: name ends with "@<M>"  or  contains "@<M> "    ("... @<M> 0.4 nozzle")
# It removes the JSON files behind those entries, the "<M>_*" assets (cover image, bed model or
# texture named after the model), and the matching entries from all four Cubicon.json lists.
set -euo pipefail
REPO="$(git rev-parse --show-toplevel)"
MANIFEST="$REPO/cubicon/version/test_only_machines.txt"
VENDOR_DIR="$REPO/resources/profiles/Cubicon"
JSON_PATH="$REPO/resources/profiles/Cubicon.json"

if [ ! -f "$MANIFEST" ]; then
  echo "  (no test_only_machines manifest; nothing to prune)"
  exit 0
fi

MODELS=()
while IFS= read -r line; do
  line="${line%%$'\r'}"
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  MODELS+=("$line")
done < "$MANIFEST"

if [ "${#MODELS[@]}" -eq 0 ]; then
  echo "  (manifest is empty; nothing to prune)"
  exit 0
fi

is_test_entry() {
  local name="$1" m
  for m in "${MODELS[@]}"; do
    [ "$name" = "$m" ] && return 0
    case "$name" in
      "$m "*) return 0 ;;
      *"@$m") return 0 ;;
      *"@$m "*) return 0 ;;
    esac
  done
  return 1
}

# 1) delete the machine/process/filament JSON files
removed_files=0
for sub in machine process filament; do
  dir="$VENDOR_DIR/$sub"
  [ -d "$dir" ] || continue
  while IFS= read -r -d '' f; do
    stem="$(basename "$f" .json)"
    if is_test_entry "$stem"; then
      rm -f "$f"
      removed_files=$((removed_files + 1))
    fi
  done < <(find "$dir" -maxdepth 1 -name '*.json' -print0)
done

# 2) delete "<model>_*" assets sitting in the vendor dir root (cover image, bed model/texture)
removed_assets=0
if [ -d "$VENDOR_DIR" ]; then
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    for m in "${MODELS[@]}"; do
      case "$base" in
        "${m}_"*) rm -f "$f"; removed_assets=$((removed_assets + 1)); break ;;
      esac
    done
  done < <(find "$VENDOR_DIR" -maxdepth 1 -type f -print0)
fi

# 3) remove matching entries from all four Cubicon.json lists
removed_entries=0
if [ -f "$JSON_PATH" ]; then
  count_entries() {
    jq '[(.machine_model_list // []), (.machine_list // []), (.process_list // []), (.filament_list // [])]
        | map(length) | add' "$1"
  }
  before_count="$(count_entries "$JSON_PATH")"
  tmp="$(mktemp)"
  # NOTE: --args routes ALL trailing positional args into $ARGS.positional (none are treated as
  # input files), so the JSON input must come via stdin redirect, not as a positional filename.
  jq --args \
    'def is_test($n): $ARGS.positional | any(. as $m |
         $n == $m or ($n | startswith($m + " ")) or ($n | endswith("@" + $m)) or ($n | contains("@" + $m + " ")));
     reduce ("machine_model_list", "machine_list", "process_list", "filament_list") as $k
       (.; if has($k) then .[$k] |= map(select(is_test(.name) | not)) else . end)' \
    "${MODELS[@]}" < "$JSON_PATH" > "$tmp"
  after_count="$(count_entries "$tmp")"
  removed_entries=$((before_count - after_count))
  mv "$tmp" "$JSON_PATH"
fi

joined="$(IFS=,; echo "${MODELS[*]}")"
echo "  pruned ${removed_files} test-only machine file(s), ${removed_assets} asset(s), ${removed_entries} Cubicon.json entr(y/ies): ${joined}"
