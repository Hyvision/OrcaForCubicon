# prune_profiles.ps1 — keep ONLY Cubicon printer profiles in resources/profiles at build time.
# OrcaForCubicon ships as a Cubicon-only slicer, so every other vendor's profiles are removed so the
# first-run wizard and the printer list show only Cubicon. The committed tree stays full-upstream;
# this prune runs from apply_overlay.ps1 after the overlay copy.
#
# Kept: Cubicon, OrcaFilamentLibrary (code-required shared filament library, no printers), blacklist.json.
$ErrorActionPreference = "Stop"
$repo = (git rev-parse --show-toplevel)
$dir  = Join-Path $repo "resources/profiles"
if (-not (Test-Path $dir)) { Write-Host "  (no resources/profiles yet)"; return }

$keep = @("Cubicon", "OrcaFilamentLibrary", "blacklist")
$removed = 0
# 1) vendor index json + its same-named dir
Get-ChildItem -Path $dir -Filter *.json -File | ForEach-Object {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
    if ($keep -contains $name) { return }
    Remove-Item -Force $_.FullName
    $vdir = Join-Path $dir $name
    if (Test-Path $vdir) { Remove-Item -Recurse -Force $vdir }
    $script:removed++
}
# 2) any leftover vendor dirs without a matching json
Get-ChildItem -Path $dir -Directory | ForEach-Object {
    if ($keep -notcontains $_.Name) { Remove-Item -Recurse -Force $_.FullName }
}
Write-Host "  pruned $removed non-Cubicon vendor profile set(s); kept: Cubicon, OrcaFilamentLibrary, blacklist"
