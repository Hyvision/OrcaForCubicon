# package_win.ps1 — build the OrcaForCubicon Windows installer (NSIS) from the
# CMake install output. Assumes the app is already built + installed
# (build/OrcaSlicer exists). Run build_win.ps1 first for a full pipeline.
param(
    [string]$MakeNsis = "C:/Program Files (x86)/NSIS/makensis.exe"
)
$ErrorActionPreference = "Stop"
$repo    = (git -C $PSScriptRoot rev-parse --show-toplevel)
$stage   = Join-Path $repo "build/OrcaSlicer"
$verHdr  = Join-Path $repo "build/src/libslic3r/libslic3r_version.h"
$brand   = Join-Path $repo "cubicon/branding"
$license = Join-Path $repo "LICENSE.txt"
$nsi     = Join-Path $repo "installer/windows/InstallScript.nsi"
$redist  = Join-Path $repo "installer/windows/redist"
# NSIS resolves a relative OutFile against the .nsi's own directory, so the installer always lands
# next to InstallScript.nsi — installer/windows/ — which is where we want it (macOS: installer/macos/).
$outDir  = Join-Path $repo "installer/windows"

foreach ($p in @($stage, $verHdr, $license, $nsi)) {
    if (-not (Test-Path $p)) { Write-Error "Missing required input: $p (build the app first?)" }
}
if (-not (Test-Path $MakeNsis)) { Write-Error "makensis not found: $MakeNsis (install NSIS)" }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "== Staging VC++/UCRT runtime DLLs app-local ==" -ForegroundColor Cyan
& (Join-Path $repo "installer/windows/CopyRuntime.ps1") -StageDir $stage -RedistDir $redist

# Ensure the Microsoft Edge WebView2 Evergreen bootstrapper is bundled. The installer runs it
# only when the target PC lacks the WebView2 Runtime; without it the config wizard / WebView
# panels show a blank page. Small (~2 MB) online bootstrapper; downloaded once, then reused.
$wv2 = Join-Path $redist "MicrosoftEdgeWebview2Setup.exe"
if (-not (Test-Path $wv2)) {
    Write-Host "== Downloading WebView2 Evergreen bootstrapper ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $redist | Out-Null
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -OutFile $wv2 -UseBasicParsing
        Write-Host "  saved $wv2"
    } catch {
        Write-Warning "WebView2 bootstrapper download failed: $($_.Exception.Message). Installer will skip the WebView2 install step."
    }
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"   # wall-clock build time -> installer filename

Write-Host "== Building NSIS installer (stamp $stamp) ==" -ForegroundColor Cyan
Push-Location $outDir   # OutFile is written here
try {
    & $MakeNsis /V3 `
        "/DSTAGE_DIR=$stage" `
        "/DVERSION_HEADER=$verHdr" `
        "/DBRANDING_DIR=$brand" `
        "/DLICENSE_FILE=$license" `
        "/DBUILD_STAMP=$stamp" `
        "$nsi"
    if ($LASTEXITCODE -ne 0) { throw "makensis failed with exit code $LASTEXITCODE" }
} finally { Pop-Location }

Write-Host "== Done. Installer(s) in $outDir ==" -ForegroundColor Green
Get-ChildItem $outDir -Filter "OrcaForCubicon Setup*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 Name,Length,LastWriteTime | Format-List
