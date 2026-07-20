# CopyRuntime.ps1 — stage VC++ (VC143) CRT + Universal CRT DLLs app-local next to
# orca-slicer.exe so the app starts on a clean PC without the VC++ Redistributable
# ("vcruntime140.dll is missing"). Also refreshes the bundled vc_redist.x64.exe.
#
#   -StageDir  : folder holding orca-slicer.exe (runtime DLLs copied here)
#   -RedistDir : installer redist folder to refresh vc_redist.x64.exe into
param(
    [Parameter(Mandatory=$true)][string]$StageDir,
    [string]$RedistDir
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $StageDir)) { Write-Error "Stage folder not found: $StageDir (build/install first)" }
if (-not $RedistDir) { $RedistDir = Join-Path $PSScriptRoot 'redist' }

function Get-NewestDir([string[]]$candidates) {
    $found = $candidates | Where-Object { Test-Path $_ } | Get-Item | Sort-Object Name -Descending
    if ($found) { return $found[0].FullName }
    return $null
}

# 1. Visual C++ CRT (msvcp140.dll, vcruntime140.dll, concrt140.dll, ...)
$vcRedistRoots = @(
    'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Redist\MSVC',
    'C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Redist\MSVC',
    'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC',
    'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC'
)
$crtDir = $null; $vcRoot = $null; $vcVer = $null
foreach ($r in $vcRedistRoots) {
    if (-not (Test-Path $r)) { continue }
    $ver = Get-NewestDir ((Get-ChildItem $r -Directory | Where-Object { $_.Name -match '^\d+\.' }).FullName)
    if ($ver) {
        $c = Join-Path $ver 'x64\Microsoft.VC143.CRT'
        if (Test-Path $c) { $crtDir = $c; $vcRoot = $r; $vcVer = Split-Path $ver -Leaf; break }
    }
}
if (-not $crtDir) { Write-Error 'Could not locate Microsoft.VC143.CRT redist (install the VC++ Redistributable component with Visual Studio).' }
Write-Host "[CRT ] $crtDir"
Copy-Item (Join-Path $crtDir '*.dll') $StageDir -Force

# 2. Universal CRT (ucrtbase.dll + api-ms-win-* forwarders)
$ucrtRoot = 'C:\Program Files (x86)\Windows Kits\10\Redist'
$ucrtDir  = $null
if (Test-Path $ucrtRoot) {
    $ver = Get-NewestDir ((Get-ChildItem $ucrtRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'ucrt\DLLs\x64') }).FullName)
    if ($ver) { $ucrtDir = Join-Path $ver 'ucrt\DLLs\x64' }
}
if (-not $ucrtDir -and (Test-Path (Join-Path $ucrtRoot 'ucrt\DLLs\x64'))) { $ucrtDir = Join-Path $ucrtRoot 'ucrt\DLLs\x64' }
if ($ucrtDir) {
    Write-Host "[UCRT] $ucrtDir"
    Copy-Item (Join-Path $ucrtDir '*.dll') $StageDir -Force
} else {
    Write-Warning 'Universal CRT app-local DLLs not found. On Windows 10/11 the OS provides UCRT, so this is usually fine.'
}

# 3. Refresh vc_redist.x64.exe used by the installer's silent system-wide install
if ($vcRoot -and $vcVer) {
    $vcExe = Join-Path (Join-Path $vcRoot $vcVer) 'vc_redist.x64.exe'
    if (Test-Path $vcExe) {
        if (-not (Test-Path $RedistDir)) { New-Item -ItemType Directory -Path $RedistDir | Out-Null }
        Copy-Item $vcExe (Join-Path $RedistDir 'vc_redist.x64.exe') -Force
        Write-Host "[EXE ] $vcExe -> $RedistDir\vc_redist.x64.exe"
    }
}
Write-Host "Runtime DLLs staged into $StageDir successfully."
