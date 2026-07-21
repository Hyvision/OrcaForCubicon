# cubicon/scripts/ — 빌드·패키징 자동화

| 스크립트 | 역할 |
|---|---|
| `apply_overlay.ps1` / `.sh` | patches 적용(`git apply --3way`) + resources 오버레이 복사 |
| `build_win.ps1` / `build_mac.sh` | **한 줄 빌드+패키지**: 오버레이 재적용 → deps(없으면만) → build → installer/DMG |
| `package_win.ps1` / `package_mac.sh` | NSIS(exe) / DMG 생성 (버전+타임스탬프 파일명 자동) |
| `set_version.ps1` / `.sh` | `version/cubicon_version.txt` 버전 출력(SSOT 확인용) |

## 한 줄 빌드 (git 업데이트 후)

```powershell
# Windows — 앱 빌드 + 인스톨러까지 한 번에
pwsh cubicon/scripts/build_win.ps1
#   -Clean        build/ 정리 후 새로 빌드
#   -Deps         의존성 강제 재빌드 (기본: 있으면 재사용)
#   -SkipPackage  인스톨러 없이 앱만
```
```bash
# macOS — 앱 빌드 + DMG까지 한 번에 (arm64 기본)
bash cubicon/scripts/build_mac.sh
#   -a x86_64|universal   아키텍처
#   -c                    build/<arch> 정리 후 새로 빌드
#   -D                    의존성 강제 재빌드
#   -P                    DMG 없이 앱만
```

산출물:
- Windows: `dist/OrcaForCubicon Setup V<버전>_<yyyymmdd_HHMMSS>.exe`
- macOS:   `dist/OrcaForCubicon_<버전>_macOS_<arch>_<yyyymmdd_HHMMSS>.dmg`

> 두 스크립트 모두 **매 실행마다 `src/`·`resources/`를 HEAD로 되돌린 뒤 오버레이를 재적용**한다.
> 즉 커밋된 SSOT(패치+리소스+버전)만으로 결정적으로 빌드하며, `src/`·`resources/`에 손으로 넣은
> 미커밋 변경은 버려진다(먼저 커밋할 것). 버전은 `version/cubicon_version.txt` 한 줄이 단일 출처.

상세 macOS 절차: [`../doc/BUILD_MACOS.md`](../doc/BUILD_MACOS.md)
