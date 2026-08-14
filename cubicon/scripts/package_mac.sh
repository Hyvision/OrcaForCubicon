#!/usr/bin/env bash
# package_mac.sh — rebrand the built OrcaSlicer.app to OrcaForCubicon.app and produce a DMG.
# Mirrors cubicon/scripts/package_win.ps1 (which drives the NSIS installer).
#
# The upstream macOS build (build_release_macos.sh, and thus build_mac.sh) always emits a
# bundle literally named OrcaSlicer.app — the name is hardcoded in src/CMakeLists.txt and
# referenced throughout build_release_macos.sh — so we rebrand as a post-build packaging step
# instead of patching the build, keeping the Cubicon overlay minimal.
#
#   -a <arch>   arm64 (default) | x86_64 | universal   (selects build/<arch>/OrcaSlicer/OrcaSlicer.app)
#   -o <dir>    output dir for the DMG (default: installer/macos/)
set -euo pipefail

ARCH=""
OUTDIR=""
while getopts ":a:o:h" opt; do
  case "$opt" in
    a) ARCH="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    h) echo "Usage: package_mac.sh [-a arm64|x86_64|universal] [-o installer/macos]"; exit 0 ;;
    *) ;;
  esac
done
[ -z "$ARCH" ] && ARCH="$(uname -m)"

REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"
[ -z "$OUTDIR" ] && OUTDIR="$REPO/installer/macos"
mkdir -p "$OUTDIR"

VER="$(tr -d '[:space:]' < cubicon/version/cubicon_version.txt)"   # SSOT, e.g. 1.5.0-rc1
SRC_APP="build/$ARCH/OrcaSlicer/OrcaSlicer.app"
[ -d "$SRC_APP" ] || { echo "!! $SRC_APP not found — run build_mac.sh -a $ARCH first." >&2; exit 1; }

STAGE="$(mktemp -d)"
DST_APP="$STAGE/OrcaForCubicon.app"
echo "== [1] Rebranding bundle -> OrcaForCubicon.app =="
cp -pR "$SRC_APP" "$DST_APP"

PLIST="$DST_APP/Contents/Info.plist"
# Display name only; CFBundleExecutable stays 'orca-slicer' (the real binary name).
/usr/libexec/PlistBuddy -c "Set :CFBundleName OrcaForCubicon"        "$PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleName string OrcaForCubicon" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName OrcaForCubicon"        "$PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string OrcaForCubicon" "$PLIST"
# CFBundleShortVersionString accepts the product version; strip any -rc suffix for CFBundleVersion
# (Apple requires CFBundleVersion to be numeric X.Y.Z).
VER_NUM="${VER%%-*}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VER"     "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VER_NUM"           "$PLIST" 2>/dev/null || true

find "$DST_APP" -name '.DS_Store' -delete 2>/dev/null || true

# Optional code signing (needs an Apple Developer identity in $CODESIGN_IDENTITY).
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  echo "== [2] Codesigning with '$CODESIGN_IDENTITY' =="
  codesign --deep --force --options runtime --sign "$CODESIGN_IDENTITY" "$DST_APP"
else
  echo "== [2] Skipping codesign (set CODESIGN_IDENTITY to enable; notarization also required for distribution) =="
fi

STAMP="$(date +%Y%m%d_%H%M%S)"   # wall-clock build time -> DMG filename
DMG="$OUTDIR/OrcaForCubicon_${VER}_macOS_${ARCH}_${STAMP}.dmg"
rm -f "$DMG"
echo "== [3] Building DMG -> $DMG =="
if command -v create-dmg >/dev/null 2>&1; then
  # create-dmg gives a nicer layout (Applications symlink, window size). brew install create-dmg
  create-dmg \
    --volname "OrcaForCubicon $VER" \
    --app-drop-link 450 180 \
    --icon "OrcaForCubicon.app" 150 180 \
    --window-size 600 380 \
    "$DMG" "$DST_APP" || { echo "create-dmg failed; falling back to hdiutil"; command -v hdiutil >/dev/null && hdiutil create -volname "OrcaForCubicon $VER" -srcfolder "$STAGE" -ov -format UDZO "$DMG"; }
else
  echo "  (create-dmg not found; using hdiutil — plain layout. brew install create-dmg for a nicer DMG.)"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "OrcaForCubicon $VER" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
fi

rm -rf "$STAGE"
echo "== package_mac.sh complete: $DMG =="
