# prune_test_machines.ps1 — RELEASE builds only.
# Removes "test-only" machines (listed in cubicon/version/test_only_machines.txt) from the STAGED
# build tree (resources/profiles/Cubicon) so an unverified printer line ships in TEST builds but not
# in RELEASE builds. Mirrors prune_test_filaments.ps1: it edits the generated resources/ copy
# (regenerated from the overlay on every build) — it never touches the overlay SSOT under
# cubicon/resources/.
#
# Matching for a manifest line <M> (a printer model name):
#   machine_model  : name == <M>
#   machine        : name == <M>  or  name starts with "<M> "        ("<M> 0.4 nozzle")
#   process/filament: name ends with "@<M>"  or  contains "@<M> "    ("... @<M> 0.4 nozzle")
# It removes the JSON files behind those entries, the "<M>_*" assets (cover image, bed model or
# texture named after the model), and the matching entries from all four Cubicon.json lists.
#
# Usage: pwsh cubicon/scripts/prune_test_machines.ps1 -RepoRoot <repo>
param(
    [Parameter(Mandatory = $true)][string]$RepoRoot
)
$ErrorActionPreference = "Stop"

$manifest  = Join-Path $RepoRoot "cubicon/version/test_only_machines.txt"
$vendorDir = Join-Path $RepoRoot "resources/profiles/Cubicon"
$jsonPath  = Join-Path $RepoRoot "resources/profiles/Cubicon.json"

if (-not (Test-Path $manifest)) {
    Write-Host "  (no test_only_machines manifest; nothing to prune)"
    return
}

$models = @(Get-Content -Encoding utf8 $manifest |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') })

if ($models.Count -eq 0) {
    Write-Host "  (manifest is empty; nothing to prune)"
    return
}

# machine_model_list entries carry the bare model name; machine_list entries add the variant suffix.
function Test-IsTestMachine([string]$name) {
    foreach ($m in $models) {
        if ($name -eq $m -or $name.StartsWith($m + " ")) { return $true }
    }
    return $false
}

# process/filament presets are named "<preset> @<model> <variant>".
function Test-IsTestPreset([string]$name) {
    foreach ($m in $models) {
        if ($name.EndsWith("@" + $m) -or $name.Contains("@" + $m + " ")) { return $true }
    }
    return $false
}

function Test-IsTestEntry([string]$name) {
    return ((Test-IsTestMachine $name) -or (Test-IsTestPreset $name))
}

# 1) delete the machine/process/filament JSON files
$removedFiles = 0
foreach ($sub in @("machine", "process", "filament")) {
    $dir = Join-Path $vendorDir $sub
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem -Path $dir -Filter *.json -File | ForEach-Object {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        if (Test-IsTestEntry $stem) {
            Remove-Item -Force $_.FullName
            $script:removedFiles++
        }
    }
}

# 2) delete "<model>_*" assets sitting in the vendor dir root (cover image, bed model/texture)
$removedAssets = 0
if (Test-Path $vendorDir) {
    Get-ChildItem -Path $vendorDir -File | ForEach-Object {
        foreach ($m in $models) {
            if ($_.Name.StartsWith($m + "_")) {
                Remove-Item -Force $_.FullName
                $script:removedAssets++
                break
            }
        }
    }
}

# 3) remove matching entries from all four Cubicon.json lists
$removedEntries = 0
if (Test-Path $jsonPath) {
    $cfg = Get-Content -Raw -Encoding utf8 $jsonPath | ConvertFrom-Json
    foreach ($listName in @("machine_model_list", "machine_list", "process_list", "filament_list")) {
        if ($cfg.PSObject.Properties.Name -notcontains $listName) { continue }
        $before = @($cfg.$listName)
        $kept   = @($before | Where-Object { -not (Test-IsTestEntry $_.name) })
        $removedEntries += ($before.Count - $kept.Count)
        # Force an array even if 0/1 items remain, so ConvertTo-Json keeps it a JSON array.
        $cfg.$listName = [System.Collections.ArrayList]@($kept)
    }
    $out = $cfg | ConvertTo-Json -Depth 30
    # Write UTF-8 WITHOUT BOM — the JSON loader (and every other profile file) expects no BOM.
    [System.IO.File]::WriteAllText($jsonPath, $out, (New-Object System.Text.UTF8Encoding($false)))
}

Write-Host ("  pruned {0} test-only machine file(s), {1} asset(s), {2} Cubicon.json entr(y/ies): {3}" -f `
    $removedFiles, $removedAssets, $removedEntries, ($models -join ', '))
