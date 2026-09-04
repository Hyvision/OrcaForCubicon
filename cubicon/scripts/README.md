# cubicon/scripts/ — 빌드·패키징 자동화

| 스크립트 | 역할 |
|---|---|
| `apply_overlay.ps1` / `.sh` | patches 적용(`git apply --3way`) + resources 오버레이 복사 |
| `build_win.ps1` / `build_mac.sh` | **한 줄 빌드+패키지**: 오버레이 재적용 → deps(없으면만) → build → installer/DMG |
| `package_win.ps1` / `package_mac.sh` | NSIS(exe) / DMG 생성 (버전+타임스탬프 파일명 자동) |
| `set_version.ps1` / `.sh` | `version/cubicon_version.txt` 버전 출력(SSOT 확인용) |
| `verify_build_volume_guard.py` | 4기종을 슬라이싱해 `START_PRINT` 의 `REQ_X/Y/Z` 가 조형 크기와 맞는지 검사 ([문서](../doc/build-volume-guard.md)) |

## 한 줄 빌드 (git 업데이트 후)

플래그 없이 실행하면 **대화형**으로 옵션을 순서대로 물어본다(엔터=기본값, 번호로 선택).
플래그를 주면 해당 항목의 기본값이 바뀌고, `-y`(win: `-y`/`-NonInteractive`)면 질문 없이 바로 진행한다.

```powershell
# Windows — 실행하면 순서대로: ① Clean? ② deps 재빌드? ③ 인스톨러 생성? → 요약 확인 → 진행
pwsh cubicon/scripts/build_win.ps1
#   -Clean        build/ 정리 후 새로 빌드
#   -Deps         의존성 강제 재빌드 (기본: 있으면 재사용)
#   -SkipPackage  인스톨러 없이 앱만
#   -y            질문 없이 비대화형(플래그/기본값) 진행
```
```bash
# macOS — 실행하면 순서대로: ① 아키텍처 ② Clean? ③ deps 재빌드? ④ DMG 생성? → 요약 확인 → 진행
bash cubicon/scripts/build_mac.sh
#   -a x86_64|universal   아키텍처 (기본 arm64)
#   -c                    build/<arch> 정리 후 새로 빌드
#   -D                    의존성 강제 재빌드
#   -P                    DMG 없이 앱만
#   -y                    질문 없이 비대화형 진행
```

산출물:
- Windows: `installer/windows/OrcaForCubicon Setup V<버전>_<yyyymmdd_HHMMSS>.exe`
- macOS:   `installer/macos/OrcaForCubicon_<버전>_macOS_<arch>_<yyyymmdd_HHMMSS>.dmg`

빌드 로그는 `dist/logs/build_win_<yyyymmdd_HHMMSS>.log` (산출물이 아니라 로그라서 분리).

> 두 스크립트 모두 **매 실행마다 `src/`·`resources/`를 HEAD로 되돌린 뒤 오버레이를 재적용**한다.
> 즉 커밋된 SSOT(패치+리소스+버전)만으로 결정적으로 빌드하며, `src/`·`resources/`에 손으로 넣은
> 미커밋 변경은 버려진다(먼저 커밋할 것). 버전은 `version/cubicon_version.txt` 한 줄이 단일 출처.

> **Windows**: `build/OrcaSlicer` 의 앱이 실행 중이면 install 단계에서 DLL 복사가 막힌다
> (`msvcp140.dll ... Permission denied` → `MSB3073`). `build_win.ps1` 이 시작 시점과 install 직전에
> 이를 확인해서, 대화형이면 종료할지 묻고 `-y` 면 바로 멈춘다. 빌드를 다 돌린 뒤 실패하지 않도록
> **시작할 때 먼저** 잡는다.

상세 macOS 절차: [`../doc/BUILD_MACOS.md`](../doc/BUILD_MACOS.md)
