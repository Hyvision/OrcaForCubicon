#!/usr/bin/env bash
# build_mac.sh — one-command OrcaForCubicon macOS build + package.
# Assumes the repo is already git-updated. Produces OrcaForCubicon.app and (by default) a DMG
# with an auto version + timestamp filename:
#   installer/macos/OrcaForCubicon_<ver>_macOS_<arch>_<yyyymmdd_HHMMSS>.dmg
#
# Run with no flags -> INTERACTIVE: asks each option in turn (Enter = default, number = pick).
# Flags override the corresponding prompt default; -y skips all prompts (for CI / piped runs).
#
#   -a <arch>     arm64 (default on Apple Silicon) | x86_64 | universal
#   -c            clean: wipe build/<arch> first for a fresh app build
#   -D            force-rebuild dependencies (otherwise reused if present)
#   -P            skip packaging (stop after the .app build)
#   -t <ver>      macOS deployment target (default 11.3)
#   -b <type>     test (default, keeps -rc suffix) | release (strips -rc suffix + prunes
#                 test-only filaments) — mirrors build_win.ps1's -BuildType
#   -y            non-interactive: use flags/defaults, ask nothing
#
# Notes:
#  * Committed src/ + resources/ are upstream-pristine; Cubicon changes live only in the overlay
#    (cubicon/patches + cubicon/resources). This script resets those trees to HEAD and re-applies
#    the overlay every run, so it always builds the committed SSOT deterministically (uncommitted
#    hand-edits under src/ or resources/ are discarded — commit them first).
set -euo pipefail
SECONDS=0

ARCH=""; CLEAN=0; FORCE_DEPS=0; SKIP_PKG=0; DEPLOY_TGT="11.3"; NONINTERACTIVE=0; CPU_PCT=70; BUILD_TYPE="test"
while getopts ":a:cDPt:b:yj:h" opt; do
  case "$opt" in
    a) ARCH="$OPTARG" ;;
    c) CLEAN=1 ;;
    D) FORCE_DEPS=1 ;;
    P) SKIP_PKG=1 ;;
    t) DEPLOY_TGT="$OPTARG" ;;
    b) BUILD_TYPE="$OPTARG" ;;
    y) NONINTERACTIVE=1 ;;
    j) CPU_PCT="$OPTARG" ;;
    h) echo "Usage: build_mac.sh [-a arm64|x86_64|universal] [-c clean] [-D force deps] [-P skip package] [-t 11.3] [-b test|release] [-j cpu%] [-y]"; exit 0 ;;
    *) ;;
  esac
done
[ -z "$ARCH" ] && ARCH="$(uname -m)"   # arm64 on Apple Silicon, x86_64 on Intel
case "$BUILD_TYPE" in
  test|release) ;;
  *) echo "!! -b must be 'test' or 'release' (got '$BUILD_TYPE')" >&2; exit 1 ;;
esac

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

# The slicer build uses CMake's "Xcode" generator, which shells out to
# xcodebuild -- that refuses to run when the active developer directory is
# the bare Command Line Tools package. Switch to the full Xcode.app if it's
# installed and not already selected (asks for sudo password once).
if [[ "$(xcode-select -p 2>/dev/null)" != *"Xcode.app"* ]]; then
  if [ -d "/Applications/Xcode.app" ]; then
    echo "== xcode-select: switching active developer directory to Xcode.app =="
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  else
    echo "!! /Applications/Xcode.app not found -- the slicer build step (CMake Xcode generator) will fail without it." >&2
  fi
fi

# Some autoconf-based deps (e.g. GMP) invoke `cc` directly without -isysroot.
# On this machine clang's implicit default-SDK lookup fails for those bare
# invocations ("ld: library 'System' not found") unless SDKROOT is set
# explicitly, so export it for the whole build (deps + slicer).
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

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
  # 5) build type
  read -r -p "5) 빌드 유형 - test(=rc 표시 유지) / release(=rc 표시 제거 + 테스트 전용 필라멘트 제외) [기본: $BUILD_TYPE]: " bt || true
  if [ -n "${bt:-}" ]; then
    bt="$(printf '%s' "$bt" | tr '[:upper:]' '[:lower:]')"
    case "$bt" in
      release|test) BUILD_TYPE="$bt" ;;
      *) echo "  알 수 없는 값 '$bt' -> '$BUILD_TYPE' 유지" ;;
    esac
  fi
  echo
  echo "요약: arch=$ARCH  clean=$([ "$CLEAN" -eq 1 ] && echo 예 || echo 아니오)  rebuild-deps=$([ "$FORCE_DEPS" -eq 1 ] && echo 예 || echo 아니오)  package=$([ "$SKIP_PKG" -eq 1 ] && echo 아니오 || echo 예)  target=$DEPLOY_TGT  build-type=$BUILD_TYPE"
  if ! ask_yesno "이대로 진행할까요?" "y"; then echo "취소됨."; exit 0; fi
  echo
fi

echo "== [1/5] Applying Cubicon overlay (reset to pristine + apply patches/resources) =="
# Reset every tree the overlay touches back to HEAD before re-applying — including the ROOT files
# some patches modify (CMakeLists.txt <- 0008, version.inc <- 0001). `git reset` first in case a
# prior `git apply --3way` left the index dirty (checkout restores from the index, not HEAD, so a
# dirty index would silently reintroduce stale overlay content instead of true pristine).
git reset -q -- src resources CMakeLists.txt version.inc 2>/dev/null || true
git checkout HEAD -- src resources CMakeLists.txt version.inc 2>/dev/null || true
bash "$REPO/cubicon/scripts/apply_overlay.sh"

# ---- Build type: 'release' strips the -rc suffix from the product version (cubicon_version.txt is
# the single source of truth read by version.inc -> CUBI_ORCA_VERSION -> version display, splash,
# About dialog, and the DMG name). We temporarily rewrite the file for the build and ALWAYS restore
# it on exit below, so the committed SSOT keeps its rc marker.
# cubicon_version.txt is under cubicon/ and is NOT reset by the `git checkout HEAD --` above.
VER_FILE="$REPO/cubicon/version/cubicon_version.txt"
RAW_VER="$(cat "$VER_FILE")"
if [ "$BUILD_TYPE" = "release" ]; then
  EFF_VER="$(printf '%s' "$RAW_VER" | sed -E 's/-rc.*$//')"
else
  EFF_VER="$RAW_VER"
fi
restore_version() {
  printf '%s' "$RAW_VER" > "$VER_FILE"
  echo "Restored version file to '$RAW_VER'"
}
if [ "$EFF_VER" != "$RAW_VER" ]; then
  printf '%s' "$EFF_VER" > "$VER_FILE"
  echo "Build type: RELEASE -> version '$EFF_VER' (stripped rc from '$RAW_VER')"
  trap restore_version EXIT
else
  echo "Build type: $(printf '%s' "$BUILD_TYPE" | tr '[:lower:]' '[:upper:]') -> version '$EFF_VER'"
fi

# ---- Release-only: drop unverified "test-only" filaments (cubicon/version/test_only_filaments.txt)
# from the generated resources/ tree so they ship in TEST builds but not RELEASE builds. This edits
# the build copy only (regenerated from the overlay each build); the SSOT under cubicon/resources
# keeps every filament. TEST builds skip this and include everything.
if [ "$BUILD_TYPE" = "release" ]; then
  echo "== [1b/5] Release: pruning test-only filaments =="
  bash "$REPO/cubicon/scripts/prune_test_filaments.sh"
fi

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
