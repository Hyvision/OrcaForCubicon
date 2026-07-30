# prune_test_filaments.ps1 — RELEASE builds only.
# Removes "test-only" filaments (listed in cubicon/version/test_only_filaments.txt) from the
# STAGED build tree (resources/profiles/Cubicon) so unverified filaments ship in TEST builds but
# not in RELEASE builds. This edits the generated resources/ copy (regenerated from the overlay on
# every build) — it never touches the overlay SSOT under cubicon/resources/.
#
# Matching: a manifest line matches a filament whose name == the line, or starts with "<line> @".
# It removes both the filament JSON files and the matching entries from Cubicon.json filament_list.
#
# Usage: pwsh cubicon/scripts/prune_test_filaments.ps1 -RepoRoot <repo>
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
)
$ErrorActionPreference = "Stop"

$manifest = Join-Path $RepoRoot "cubicon/version/test_only_filaments.txt"
$filDir   = Join-Path $RepoRoot "resources/profiles/Cubicon/filament"
$jsonPath = Join-Path $RepoRoot "resources/profiles/Cubicon.json"

if (-not (Test-Path $manifest)) {
    Write-Host "  (no test_only_filaments manifest; nothing to prune)"
    return
}

$prefixes = @(Get-Content -Encoding utf8 $manifest |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') })

if ($prefixes.Count -eq 0) {
    Write-Host "  (manifest is empty; nothing to prune)"
    return
}

function Test-IsTestOnly([string]$name) {
    foreach ($p in $prefixes) {
        if ($name -eq $p -or $name.StartsWith($p + " @")) { return $true }
    }
    return $false
}

# 1) delete matching filament JSON files
$removedFiles = 0
if (Test-Path $filDir) {
    Get-ChildItem -Path $filDir -Filter *.json -File | ForEach-Object {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        if (Test-IsTestOnly $stem) {
            Remove-Item -Force $_.FullName
            $script:removedFiles++
        }
    }
}

# 2) remove matching entries from Cubicon.json filament_list
$removedEntries = 0
if (Test-Path $jsonPath) {
    $cfg = Get-Content -Raw -Encoding utf8 $jsonPath | ConvertFrom-Json
    if ($cfg.PSObject.Properties.Name -contains 'filament_list') {
        $before = @($cfg.filament_list)
        $kept   = @($before | Where-Object { -not (Test-IsTestOnly $_.name) })
        $removedEntries = $before.Count - $kept.Count
        # Force an array even if 0/1 items remain, so ConvertTo-Json keeps it a JSON array.
        $cfg.filament_list = [System.Collections.ArrayList]@($kept)
        $out = $cfg | ConvertTo-Json -Depth 30
        # Write UTF-8 WITHOUT BOM — the JSON loader (and every other profile file) expects no BOM.
        [System.IO.File]::WriteAllText($jsonPath, $out, (New-Object System.Text.UTF8Encoding($false)))
    }
}

Write-Host ("  pruned {0} test-only filament file(s), {1} filament_list entr(y/ies): {2}" -f `
    $removedFiles, $removedEntries, ($prefixes -join ', '))
