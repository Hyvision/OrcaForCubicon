# apply_overlay.ps1 — Cubicon 오버레이를 업스트림 트리에 적용 (Windows/PowerShell)
# 1) cubicon/patches/*.patch 를 순서대로 git apply --3way
# 2) cubicon/resources/* 를 업스트림 resources/ 위로 덮어쓰기 복사
# 사용: pwsh cubicon/scripts/apply_overlay.ps1  (repo 루트에서 실행)

$ErrorActionPreference = "Stop"
$RepoRoot = (git rev-parse --show-toplevel)
Set-Location $RepoRoot

Write-Host "== [1/2] Applying patches ==" -ForegroundColor Cyan
$patches = Get-ChildItem -Path "cubicon/patches" -Filter "*.patch" -ErrorAction SilentlyContinue | Sort-Object Name
if ($patches.Count -eq 0) {
    Write-Host "  (no patches yet)"
} else {
    foreach ($p in $patches) {
        Write-Host "  apply $($p.Name)"
        git apply --3way --whitespace=nowarn $p.FullName
        if ($LASTEXITCODE -ne 0) { throw "patch failed: $($p.Name) — resolve conflicts manually" }
    }
}

Write-Host "== [2/2] Copying resource overlay ==" -ForegroundColor Cyan
$src = Join-Path $RepoRoot "cubicon/resources"
$dst = Join-Path $RepoRoot "resources"
if (Test-Path $src) {
    Get-ChildItem -Path $src -Recurse -File | Where-Object { $_.Name -ne "README.md" } | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1)
        $target = Join-Path $dst $rel
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item $_.FullName $target -Force
        Write-Host "  -> resources/$rel"
    }
} else {
    Write-Host "  (no resource overlay yet)"
}
Write-Host "Done." -ForegroundColor Green
