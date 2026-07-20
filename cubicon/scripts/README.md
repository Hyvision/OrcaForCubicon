# cubicon/scripts/ — 빌드·패키징 자동화

| 스크립트 | 역할 | 상태 |
|---|---|---|
| `apply_overlay.ps1` / `.sh` | patches 적용 + resources 오버레이 복사 | 구현됨 (빈 오버레이면 no-op) |
| `set_version.ps1` / `.sh` | `version/cubicon_version.txt` → 버전 헤더·인스톨러·default_profile 동기화 | 스텁 (Phase 2) |
| `build_win.ps1` / `build_mac.sh` | deps 빌드 → apply_overlay → build_release* 래퍼 | 스텁 (Phase 5/6) |
| `package_win.ps1` / `package_mac.sh` | NSIS(exe) / DMG 생성 | 스텁 (Phase 5/6) |

## 표준 빌드 순서
```
# Windows
pwsh cubicon/scripts/set_version.ps1
pwsh cubicon/scripts/apply_overlay.ps1
./build_release.bat
pwsh cubicon/scripts/package_win.ps1

# macOS
bash cubicon/scripts/set_version.sh
bash cubicon/scripts/apply_overlay.sh
./build_release_macos.sh
bash cubicon/scripts/package_mac.sh
```
