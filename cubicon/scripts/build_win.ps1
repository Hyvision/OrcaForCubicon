# build_win.ps1 — one-command OrcaForCubicon Windows build + package.
# Assumes the repo is already git-updated. Produces the app and (by default) the NSIS installer
# with an auto version + timestamp filename:  dist/OrcaForCubicon Setup V<ver>_<yyyymmdd_HHMMSS>.exe
#
#   (no args)     apply overlay -> build app -> package installer   (deps auto-built only if missing)
#   -Clean        wipe build/ first for a clean app build
#   -Deps         force-rebuild dependencies (otherwise reused if deps/build/OrcaSlicer_dep exists)
#   -SkipPackage  stop after build/install (no installer)
#
# Notes:
#  * The committed src/ + resources/ are upstream-pristine; Cubicon changes live only in the
#    overlay (cubicon/patches + cubicon/resources). This script resets those trees to HEAD and
#    re-applies the overlay every run, so it always builds the committed SSOT deterministically
#    (any uncommitted hand-edits under src/ or resources/ are discarded — commit them first).
param(
    [switch]$Clean,
    [switch]$Deps,
    [switch]$SkipPackage
)
$ErrorActionPreference = "Stop"
$repo  = (git -C $PSScriptRoot rev-parse --show-toplevel)
$cmake = "C:/Program Files/CMake/bin/cmake.exe"
$gen   = "Visual Studio 17 2022"     # NOTE: needs VS2022 (build_release.bat hardcodes VS2019)
$depOut = "$repo/deps/build/OrcaSlicer_dep/usr/local"

# Strawberry Perl must be FIRST for OpenSSL's Configure (msys/Git perl is rejected).
# Do NOT add Strawberry c/bin — its bundled cmake shadows the system cmake.
$env:PATH = "C:/MyDevelop/Strawberry/perl/bin;" + $env:PATH
Set-Location $repo

Write-Host "== [1/5] Applying Cubicon overlay (reset to pristine + apply patches/resources) ==" -ForegroundColor Cyan
git checkout -- src resources 2>$null    # discard prior overlay application; ignore if nothing to reset
& "$repo/cubicon/scripts/apply_overlay.ps1"

if ($Deps -or -not (Test-Path $depOut)) {
    Write-Host "== [2/5] Building dependencies (Release) ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path "$repo/deps/build" | Out-Null
    Push-Location "$repo/deps/build"
    try {
        & $cmake .. -G $gen -A x64 -DCMAKE_BUILD_TYPE=Release
        if ($LASTEXITCODE -ne 0) { throw "deps configure failed" }
        & $cmake --build . --config Release --target deps -- -m
        if ($LASTEXITCODE -ne 0) { throw "deps build failed (see notes: OpenSSL perl / Boost extract)" }
    } finally { Pop-Location }
} else {
    Write-Host "== [2/5] Reusing existing dependencies ($depOut) — pass -Deps to rebuild ==" -ForegroundColor DarkGray
}

if ($Clean -and (Test-Path "$repo/build")) {
    Write-Host "== [3/5] Clean: removing build/ ==" -ForegroundColor Cyan
    Remove-Item -Recurse -Force "$repo/build"
} else {
    Write-Host "== [3/5] Incremental build (pass -Clean for a fresh build/) ==" -ForegroundColor DarkGray
}

Write-Host "== [4/5] Configure + build + install app ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "$repo/build" | Out-Null
Push-Location "$repo/build"
try {
    & $cmake .. -G $gen -A x64 -DCMAKE_BUILD_TYPE=Release
    if ($LASTEXITCODE -ne 0) { throw "app configure failed" }
    & $cmake --build . --config Release --target ALL_BUILD -- -m
    if ($LASTEXITCODE -ne 0) { throw "app build failed" }
    & $cmake --build . --config Release --target install
    if ($LASTEXITCODE -ne 0) { throw "app install failed" }
} finally { Pop-Location }

if (-not $SkipPackage) {
    Write-Host "== [5/5] Packaging installer ==" -ForegroundColor Cyan
    & "$repo/cubicon/scripts/package_win.ps1"
} else {
    Write-Host "== [5/5] Skipped packaging (-SkipPackage) — app at build/OrcaSlicer ==" -ForegroundColor DarkGray
}
Write-Host "== build_win.ps1 complete ==" -ForegroundColor Green
