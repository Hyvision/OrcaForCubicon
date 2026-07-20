# build_win.ps1 — full one-shot OrcaForCubicon Windows pipeline:
#   deps (if needed) -> apply overlay -> configure/build/install -> package (NSIS)
# Bakes in the Windows build gotchas learned during bring-up.
#
#   -SkipDeps     skip the deps build (use existing deps/build/OrcaSlicer_dep)
#   -SkipPackage  stop after the app build/install (no installer)
param(
    [switch]$SkipDeps,
    [switch]$SkipPackage
)
$ErrorActionPreference = "Stop"
$repo  = (git -C $PSScriptRoot rev-parse --show-toplevel)
$cmake = "C:/Program Files/CMake/bin/cmake.exe"
$gen   = "Visual Studio 17 2022"     # NOTE: build_release.bat hardcodes VS2019; we need 2022

# Strawberry Perl must be FIRST for OpenSSL's Configure (msys/Git perl is rejected).
# Do NOT add Strawberry c/bin — its bundled cmake 3.29 shadows the system cmake.
$env:PATH = "C:/MyDevelop/Strawberry/perl/bin;" + $env:PATH
Set-Location $repo

if (-not $SkipDeps) {
    Write-Host "== [1] Building dependencies (Release) ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path "$repo/deps/build" | Out-Null
    Push-Location "$repo/deps/build"
    try {
        & $cmake .. -G $gen -A x64 -DCMAKE_BUILD_TYPE=Release
        if ($LASTEXITCODE -ne 0) { throw "deps configure failed" }
        # Serial for OpenSSL to avoid C1041 PDB contention; Boost 1.84 tarball may need
        # manual extraction (CMake libarchive bug) — see cubicon/doc design notes.
        & $cmake --build . --config Release --target deps -- -m
        if ($LASTEXITCODE -ne 0) { throw "deps build failed (see notes: OpenSSL perl / Boost extract)" }
    } finally { Pop-Location }
}

Write-Host "== [2] Applying Cubicon overlay ==" -ForegroundColor Cyan
& "$repo/cubicon/scripts/apply_overlay.ps1"

Write-Host "== [3] Configure + build + install app ==" -ForegroundColor Cyan
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
    Write-Host "== [4] Packaging installer ==" -ForegroundColor Cyan
    & "$repo/cubicon/scripts/package_win.ps1"
}
Write-Host "== build_win.ps1 complete ==" -ForegroundColor Green
