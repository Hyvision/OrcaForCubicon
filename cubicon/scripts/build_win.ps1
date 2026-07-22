# build_win.ps1 — one-command OrcaForCubicon Windows build + package.
# Assumes the repo is already git-updated. Produces the app and (by default) the NSIS installer
# with an auto version + timestamp filename:  dist/OrcaForCubicon Setup V<ver>_<yyyymmdd_HHMMSS>.exe
#
# Run with no flags -> INTERACTIVE: asks each option in turn (Enter = default, number = pick).
# Flags override the corresponding prompt default; -y (or -NonInteractive) skips all prompts.
#
#   -Clean        wipe build/ first for a clean app build
#   -Deps         force-rebuild dependencies (otherwise reused if present)
#   -SkipPackage  stop after build/install (no installer)
#   -y            non-interactive: use flags/defaults, ask nothing (for CI)
#
# Notes:
#  * Committed src/ + resources/ are upstream-pristine; Cubicon changes live only in the overlay
#    (cubicon/patches + cubicon/resources). This script resets those trees to HEAD and re-applies
#    the overlay every run, so it always builds the committed SSOT deterministically (uncommitted
#    hand-edits under src/ or resources/ are discarded — commit them first).
param(
    [switch]$Clean,
    [switch]$Deps,
    [switch]$SkipPackage,
    [Alias("y")][switch]$NonInteractive,
    [int]$CpuPercent = 70          # cap build CPU usage (~% of logical cores); keeps the PC usable
)
$ErrorActionPreference = "Stop"
$repo  = (git -C $PSScriptRoot rev-parse --show-toplevel)
$cmake = "C:/Program Files/CMake/bin/cmake.exe"
$gen   = "Visual Studio 17 2022"     # NOTE: needs VS2022 (build_release.bat hardcodes VS2019)
$depOut = "$repo/deps/build/OrcaSlicer_dep/usr/local"

# CPU throttling: cap the number of parallel compiler processes to ~CpuPercent of the logical
# cores so the machine stays responsive. MSVC has TWO parallelism levels that both default to all
# cores — the compiler's /MP (files within a project) and MSBuild's /m (projects). We cap /MP to
# $jobs and build one project at a time (-m:1) so the total cl.exe count never exceeds $jobs.
$cores = [int]$env:NUMBER_OF_PROCESSORS
if ($cores -lt 1) { $cores = 1 }
$pct = [Math]::Min(100, [Math]::Max(10, $CpuPercent))
$jobs = [Math]::Max(1, [int][Math]::Floor($cores * $pct / 100.0))
Write-Host ("CPU throttle: {0}% of {1} cores -> {2} parallel compile job(s)" -f $pct, $cores, $jobs) -ForegroundColor DarkGray

function Ask-YesNo([string]$question, [bool]$default) {
    $suffix = if ($default) { "[Y/n]" } else { "[y/N]" }
    $ans = Read-Host "$question $suffix"
    if ([string]::IsNullOrWhiteSpace($ans)) { return $default }
    return ($ans.Trim() -match '^[Yy]')
}

# --- Resolve options (defaults from flags), then prompt unless non-interactive ---
$optClean   = [bool]$Clean
$optDeps    = [bool]$Deps
$optPackage = -not [bool]$SkipPackage

$interactive = (-not $NonInteractive) -and (-not [System.Console]::IsInputRedirected)
if ($interactive) {
    Write-Host ""
    Write-Host "=== OrcaForCubicon Windows 빌드 옵션 (Enter=기본값) ===" -ForegroundColor Cyan
    $depsPresent = Test-Path $depOut
    Write-Host ("  현재 의존성(deps): {0}" -f $(if ($depsPresent) { '있음 (재사용 가능)' } else { '없음 (최초 빌드 필요)' })) -ForegroundColor DarkGray
    $optClean   = Ask-YesNo "1) build/ 폴더를 정리하고 새로 빌드할까요?" $optClean
    $optDeps    = Ask-YesNo "2) 의존성(deps)을 강제로 다시 빌드할까요?" $optDeps
    $optPackage = Ask-YesNo "3) 인스톨러(.exe)까지 생성할까요?" $optPackage
    Write-Host ""
    Write-Host "요약:" -ForegroundColor Cyan
    Write-Host ("  - Clean build : {0}" -f $(if ($optClean) { '예' } else { '아니오' }))
    Write-Host ("  - Rebuild deps: {0}" -f $(if ($optDeps) { '예' } else { $(if ($depsPresent) { '아니오 (재사용)' } else { '예 (없어서 자동)' }) }))
    Write-Host ("  - Package     : {0}" -f $(if ($optPackage) { '예 (installer)' } else { '아니오 (앱만)' }))
    if (-not (Ask-YesNo "이대로 진행할까요?" $true)) { Write-Host "취소됨." -ForegroundColor Yellow; return }
}

# Strawberry Perl must be FIRST for OpenSSL's Configure (msys/Git perl is rejected).
# Do NOT add Strawberry c/bin — its bundled cmake shadows the system cmake.
$env:PATH = "C:/MyDevelop/Strawberry/perl/bin;" + $env:PATH
Set-Location $repo

Write-Host "== [1/5] Applying Cubicon overlay (reset to pristine + apply patches/resources) ==" -ForegroundColor Cyan
git checkout -- src resources 2>$null    # discard prior overlay application; ignore if nothing to reset
& "$repo/cubicon/scripts/apply_overlay.ps1"

if ($optDeps -or -not (Test-Path $depOut)) {
    Write-Host "== [2/5] Building dependencies (Release) ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path "$repo/deps/build" | Out-Null
    Push-Location "$repo/deps/build"
    try {
        & $cmake .. -G $gen -A x64 -DCMAKE_BUILD_TYPE=Release
        if ($LASTEXITCODE -ne 0) { throw "deps configure failed" }
        # Cap MSBuild project-parallelism for deps (sub-builds may still spike briefly; deps is a
        # one-time cost, reused afterwards via -SkipDeps / auto-skip). Use CMake's --parallel so it
        # emits a correctly-formatted /m:N (passing "-- -m:N" gets mangled into "-m: N" -> MSB1031).
        & $cmake --build . --config Release --target deps --parallel $jobs
        if ($LASTEXITCODE -ne 0) { throw "deps build failed (see notes: OpenSSL perl / Boost extract)" }
    } finally { Pop-Location }
} else {
    Write-Host "== [2/5] Reusing existing dependencies ($depOut) ==" -ForegroundColor DarkGray
}

if ($optClean -and (Test-Path "$repo/build")) {
    Write-Host "== [3/5] Clean: removing build/ ==" -ForegroundColor Cyan
    Remove-Item -Recurse -Force "$repo/build"
} else {
    Write-Host "== [3/5] Incremental build ==" -ForegroundColor DarkGray
}

Write-Host "== [4/5] Configure + build + install app ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path "$repo/build" | Out-Null
# Recover from an earlier throttle build that clobbered CMAKE_CXX_FLAGS (=/MP<n>, dropping the
# MSVC defaults like /DWIN32 -> C1017). If detected, wipe the cache for a clean, correct reconfigure.
$cacheFile = "$repo/build/CMakeCache.txt"
if (Test-Path $cacheFile) {
    $cxxLine = (Select-String -Path $cacheFile -Pattern '^CMAKE_CXX_FLAGS:' | Select-Object -First 1).Line
    if ($cxxLine -and ($cxxLine -match '/MP') -and ($cxxLine -notmatch 'WIN32')) {
        Write-Host "  Detected a poisoned CMake cache (CXX flags = '$cxxLine'); removing build/ for a clean reconfigure." -ForegroundColor Yellow
        Remove-Item -Recurse -Force "$repo/build"
        New-Item -ItemType Directory -Force -Path "$repo/build" | Out-Null
    }
}
Push-Location "$repo/build"
try {
    # Throttle via SLIC3R_MSVC_PARALLEL_COUNT (adds /MP:$jobs to the existing flags — does NOT
    # replace CMAKE_CXX_FLAGS, so the MSVC defaults /DWIN32 /D_WINDOWS /EHsc stay intact), then
    # build one project at a time (--parallel 1) so total parallel cl.exe == $jobs (~CpuPercent).
    & $cmake .. -G $gen -A x64 -DCMAKE_BUILD_TYPE=Release "-DSLIC3R_MSVC_PARALLEL_COUNT=$jobs"
    if ($LASTEXITCODE -ne 0) { throw "app configure failed" }
    # --parallel 1: build one project at a time so total cl.exe == the /MP:$jobs file-level cap
    # (~CpuPercent of cores). CMake emits a correct /m:1 (avoids the "-- -m:1" -> MSB1031 mangling).
    & $cmake --build . --config Release --target ALL_BUILD --parallel 1
    if ($LASTEXITCODE -ne 0) { throw "app build failed" }
    & $cmake --build . --config Release --target install
    if ($LASTEXITCODE -ne 0) { throw "app install failed" }
} finally { Pop-Location }

if ($optPackage) {
    Write-Host "== [5/5] Packaging installer ==" -ForegroundColor Cyan
    & "$repo/cubicon/scripts/package_win.ps1"
} else {
    Write-Host "== [5/5] Skipped packaging — app at build/OrcaSlicer ==" -ForegroundColor DarkGray
}
Write-Host "== build_win.ps1 complete ==" -ForegroundColor Green
