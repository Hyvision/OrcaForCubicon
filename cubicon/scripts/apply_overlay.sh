#!/usr/bin/env bash
# apply_overlay.sh — Cubicon 오버레이를 업스트림 트리에 적용 (macOS/Linux)
# 1) cubicon/patches/*.patch 를 순서대로 git apply --3way
# 2) cubicon/resources/* 를 업스트림 resources/ 위로 덮어쓰기 복사
# 사용: bash cubicon/scripts/apply_overlay.sh  (repo 루트에서 실행)
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "== [1/2] Applying patches =="
shopt -s nullglob
patches=(cubicon/patches/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
  echo "  (no patches yet)"
else
  for p in $(printf '%s\n' "${patches[@]}" | sort); do
    echo "  apply $p"
    git apply --3way --whitespace=nowarn "$p" || { echo "patch failed: $p — resolve manually"; exit 1; }
  done
fi

echo "== [2/2] Copying resource overlay =="
if [ -d cubicon/resources ]; then
  ( cd cubicon/resources && find . -type f ! -name README.md -print0 ) | \
  while IFS= read -r -d '' f; do
    rel="${f#./}"
    mkdir -p "resources/$(dirname "$rel")"
    cp -f "cubicon/resources/$rel" "resources/$rel"
    echo "  -> resources/$rel"
  done
else
  echo "  (no resource overlay yet)"
fi

echo "== [3/3] Pruning to Cubicon-only profiles =="
bash "$REPO_ROOT/cubicon/scripts/prune_profiles.sh"

echo "Done."
