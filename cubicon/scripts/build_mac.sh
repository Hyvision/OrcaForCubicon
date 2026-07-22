#!/usr/bin/env bash
# build_mac.sh — one-command OrcaForCubicon macOS build + package.
# Assumes the repo is already git-updated. Produces OrcaForCubicon.app and (by default) a DMG
# with an auto version + timestamp filename:  dist/OrcaForCubicon_<ver>_macOS_<arch>_<yyyymmdd_HHMMSS>.dmg
#
# Run with no flags -> INTERACTIVE: asks each option in turn (Enter = default, number = pick).
# Flags override the corresponding prompt default; -y skips all prompts (for CI / piped runs).
#
#   -a <arch>     arm64 (default on Apple Silicon) | x86_64 | universal
#   -c            clean: wipe build/<arch> first for a fresh app build
#   -D            force-rebuild dependencies (otherwise reused if present)
#   -P            skip packaging (stop after the .app build)
#   -t <ver>      macOS deployment target (default 11.3)
#   -y            non-interactive: use flags/defaults, ask nothing
#
# Notes:
#  * Committed src/ + resources/ are upstream-pristine; Cubicon changes live only in the overlay
#    (cubicon/patches + cubicon/resources). This script resets those trees to HEAD and re-applies
#    the overlay every run, so it always builds the committed SSOT deterministically (uncommitted
#    hand-edits under src/ or resources/ are discarded — commit them first).
set -euo pipefail
SECONDS=0

ARCH=""; CLEAN=0; FORCE_DEPS=0; SKIP_PKG=0; DEPLOY_TGT="11.3"; NONINTERACTIVE=0; CPU_PCT=70
while getopts ":a:cDPt:yj:h" opt; do
  case "$opt" in
    a) ARCH="$OPTARG" ;;
    c) CLEAN=1 ;;
    D) FORCE_DEPS=1 ;;
    P) SKIP_PKG=1 ;;
    t) DEPLOY_TGT="$OPTARG" ;;
    y) NONINTERACTIVE=1 ;;
    j) CPU_PCT="$OPTARG" ;;
    h) echo "Usage: build_mac.sh [-a arm64|x86_64|universal] [-c clean] [-D force deps] [-P skip package] [-t 11.3] [-j cpu%] [-y]"; exit 0 ;;
    *) ;;
  esac
done
[ -z "$ARCH" ] && ARCH="$(uname -m)"   # arm64 on Apple Silicon, x86_64 on Intel

# CPU throttling: cap parallel build jobs to ~CPU_PCT% of the logical cores so the machine stays
# usable. Clang has no /MP; Ninja/Xcode honor CMAKE_BUILD_PARALLEL_LEVEL, so one knob caps both
# the deps and slicer builds (build_release_macos.sh uses `cmake --build`).
CORES="$(sysctl -n hw.logicalcpu 2>/dev/null || nproc 2>/dev/null || echo 8)"
[ "$CPU_PCT" -lt 10 ] && CPU_PCT=10; [ "$CPU_PCT" -gt 100 ] && CPU_PCT=100
JOBS=$(( CORES * CPU_PCT / 100 )); [ "$JOBS" -lt 1 ] && JOBS=1
export CMAKE_BUILD_PARALLEL_LEVEL="$JOBS"
echo "CPU throttle: ${CPU_PCT}% of ${CORES} cores -> ${JOBS} parallel build job(s)"

REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"

ask_yesno() {   # $1=question  $2=default(y|n) ; returns 0 for yes
  local q="$1" def="$2" ans suffix
  if [ "$def" = "y" ]; then suffix="[Y/n]"; else suffix="[y/N]"; fi
  read -r -p "$q $suffix " ans || true
  ans="${ans:-$def}"
  case "$ans" in [Yy]*) return 0;; *) return 1;; esac
}

# --- Interactive prompts (only on a real TTY and unless -y) ---
if [ "$NONINTERACTIVE" -ne 1 ] && [ -t 0 ]; then
  echo
  echo "=== OrcaForCubicon macOS 빌드 옵션 (Enter=기본값) ==="
  # 1) architecture
  echo "1) 아키텍처를 선택하세요:"
  echo "     1) $ARCH (default)"
  echo "     2) arm64"
  echo "     3) x86_64"
  echo "     4) universal"
  read -r -p "   선택 [1]: " a || true
  case "${a:-1}" in
    1) : ;;                 # keep detected/flagged ARCH
    2) ARCH="arm64" ;;
    3) ARCH="x86_64" ;;
    4) ARCH="universal" ;;
    *) : ;;
  esac
  # 2) clean
  if ask_yesno "2) build/$ARCH 를 정리하고 새로 빌드할까요?" "$([ "$CLEAN" -eq 1 ] && echo y || echo n)"; then CLEAN=1; else CLEAN=0; fi
  # 3) deps
  deps_present="없음 (최초 빌드 필요)"; [ -d "deps/build/$ARCH/OrcaSlicer_dep" ] && deps_present="있음 (재사용 가능)"
  echo "   현재 의존성(deps, $ARCH): $deps_present"
  if ask_yesno "3) 의존성(deps)을 강제로 다시 빌드할까요?" "$([ "$FORCE_DEPS" -eq 1 ] && echo y || echo n)"; then FORCE_DEPS=1; else FORCE_DEPS=0; fi
  # 4) package
  if ask_yesno "4) DMG 패키지까지 생성할까요?" "$([ "$SKIP_PKG" -eq 1 ] && echo n || echo y)"; then SKIP_PKG=0; else SKIP_PKG=1; fi
  echo
  echo "요약: arch=$ARCH  clean=$([ "$CLEAN" -eq 1 ] && echo 예 || echo 아니오)  rebuild-deps=$([ "$FORCE_DEPS" -eq 1 ] && echo 예 || echo 아니오)  package=$([ "$SKIP_PKG" -eq 1 ] && echo 아니오 || echo 예)  target=$DEPLOY_TGT"
  if ! ask_yesno "이대로 진행할까요?" "y"; then echo "취소됨."; exit 0; fi
  echo
fi

echo "== [1/5] Applying Cubicon overlay (reset to pristine + apply patches/resources) =="
# Reset every tree the overlay touches back to HEAD before re-applying — including the ROOT files
# some patches modify (CMakeLists.txt <- 0007, version.inc <- 0001); otherwise a prior apply_overlay
# leaves them dirty vs the index and `git apply` fails "does not match index".
git checkout -- src resources CMakeLists.txt version.inc 2>/dev/null || true
bash "$REPO/cubicon/scripts/apply_overlay.sh"

DEPS_MARK="deps/build/$ARCH/OrcaSlicer_dep"
if [ "$FORCE_DEPS" -eq 1 ] || [ ! -d "$DEPS_MARK" ]; then
  echo "== [2/5] Building dependencies ($ARCH) =="
  ./build_release_macos.sh -d -a "$ARCH" -t "$DEPLOY_TGT"
else
  echo "== [2/5] Reusing existing dependencies ($DEPS_MARK) =="
fi

if [ "$CLEAN" -eq 1 ] && [ -d "build/$ARCH" ]; then
  echo "== [3/5] Clean: removing build/$ARCH =="
  rm -rf "build/$ARCH"
else
  echo "== [3/5] Incremental build =="
fi

echo "== [4/5] Building slicer ($ARCH) =="
./build_release_macos.sh -s -a "$ARCH" -t "$DEPLOY_TGT"

APP="build/$ARCH/OrcaSlicer/OrcaSlicer.app"   # bundle name is hardcoded upstream; rebranded in package_mac.sh
[ -d "$APP" ] || { echo "!! build finished but $APP not found — check the log above." >&2; exit 1; }

if [ "$SKIP_PKG" -eq 1 ]; then
  echo "== [5/5] Skipped packaging — app at $APP =="
else
  echo "== [5/5] Packaging DMG =="
  bash "$REPO/cubicon/scripts/package_mac.sh" -a "$ARCH"
fi

elapsed=$SECONDS
printf "== build_mac.sh complete in %dh %dm %ds ==\n" $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60))
