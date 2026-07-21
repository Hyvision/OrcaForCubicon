# OrcaForCubicon (통합 Win/Mac 소스)

**OrcaSlicer v2.4.2** 업스트림(CMake, 크로스플랫폼)을 기반으로, Cubicon 커스터마이징을
격리된 오버레이로 얹어 **Windows/macOS를 하나의 소스 트리**에서 빌드·패키징하는 저장소입니다.

- 업스트림 기반: `v2.4.2-base` 태그 (`upstream` = https://github.com/OrcaSlicer/OrcaSlicer)
- Cubicon 자산: `cubicon/` (오버레이) + `installer/` (패키징)
- 설계·계획: [`cubicon/doc/OrcaForCubicon_통합빌드_설계.md`](cubicon/doc/OrcaForCubicon_통합빌드_설계.md)
- 오버레이 개요: [`cubicon/README.md`](cubicon/README.md)

## 커스터마이징 요소
| 요소 | 위치 | 방식 |
|---|---|---|
| 제품명 / 버전 | `version.inc`, `libslic3r_version.h.in`, `cubicon/version/cubicon_version.txt` | patch + SSOT |
| GUI 문자열·분기 | `cubicon/patches/` | git patch |
| Splash | `cubicon/resources/images/`, patch | overlay + patch |
| Cubicon 프로파일 | `cubicon/resources/profiles/` | overlay 복사 |
| 인스톨러 | `installer/` | 패키징 스크립트 |

## 진행 단계
- [x] Phase 1 — 통합 repo 스캐폴딩
- [x] Phase 2 — 브랜딩·버전 오버레이 (제품명/About/스플래시에 OrcaForCubicon + 버전 표기)
- [x] Phase 3 — Cubicon 프로파일 이식 (xCeler-I/Plus/Mini)
- [x] Phase 4 — 소스 패치 재적용 (`0001`~`0005`: 브랜딩·마우스·About·**per-filament 첫레이어 override**·앱 풀네임/버전표시)
- [x] Phase 5 — Windows 패키징(NSIS, 사전 릴리스 버전 표기 대응)
- [~] Phase 6 — macOS 빌드·DMG — **스크립트+문서 준비 완료**(`cubicon/scripts/build_mac.sh`·`package_mac.sh`, [`cubicon/doc/BUILD_MACOS.md`](cubicon/doc/BUILD_MACOS.md)); Mac PC에서 빌드·검증 대기

현재 버전 SSOT: `cubicon/version/cubicon_version.txt` = **1.5.0-rc1** (통합 빌드 첫 사전 릴리스).

## 업스트림 업데이트(리베이스)
```
git fetch upstream --tags
git rebase v<new>            # 또는 merge
bash cubicon/scripts/apply_overlay.sh   # patch 재적용(충돌 수선) + resources 복사
```
