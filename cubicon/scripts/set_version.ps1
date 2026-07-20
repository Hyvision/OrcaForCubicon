# set_version.ps1 — cubicon_version.txt 를 단일 출처로 버전 동기화 (STUB — Phase 2)
# 향후 구현 대상:
#   - cubicon/version/cubicon_version.txt 읽기 (예: 1.5.0)
#   - src/libslic3r/libslic3r_version.h.in 의 CUBI_ORCA_VERSION 갱신 (patch로 추가된 매크로)
#   - installer/default_profile/OrcaForCubicon_x.y.z 폴더명 갱신
#   - 인스톨러 산출물 이름 변수 세팅
$ver = (Get-Content "cubicon/version/cubicon_version.txt" -Raw).Trim()
Write-Host "CUBI_ORCA_VERSION = $ver"
Write-Host "[stub] version sync not yet implemented (Phase 2)"
