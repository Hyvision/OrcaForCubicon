# OrcaForCubicon 이관 진행 상황 핸드오프 (2026-07-21)

> **목적**: `Cubicreator_Orca.git`(구, VS 솔루션 기반) → `OrcaForCubicon.git`(신, upstream 2.4.2 CMake + Cubicon 오버레이)
> 로 재작업 중. 이 문서는 **새 저장소에서 세션을 새로 시작해 작업을 이어받기 위한** 상태 정리다.
> 배경 설계: [`OrcaForCubicon_통합빌드_설계.md`](OrcaForCubicon_통합빌드_설계.md)

---

## 1. 두 저장소 현재 위치

| | 구 저장소 `Cubicreator_Orca.git` | 신 저장소 `OrcaForCubicon.git` (여기) |
|---|---|---|
| 구조 | 손으로 만든 VS 솔루션(`CubicreatorHS.sln`), OrcaSlicer 소스를 `Dependencies/shared/`에 평탄화. SoftFever **2.3.1-dev** 기반 | upstream OrcaSlicer **v2.4.2**(CMake, 크로스플랫폼) + Cubicon 격리 오버레이(`cubicon/`, `installer/`) |
| 버전 SSOT | `Dependencies/shared/libslic3r/libslic3r_version.h` → `CUBI_ORCA_VERSION "1.4.1"` | `cubicon/version/cubicon_version.txt` → **1.5.0** |
| 활성 브랜치 | `feature/per-filament-first-layer-speed` (main보다 6커밋 앞 — 전부 프로파일 배치/WebView 툴링, 기능 아님) | `main` |
| 상태 | 유지보수/참조용. **여기서 신규 개발 금지** | **여기가 앞으로의 본선** |

신 저장소 완료 단계(메모리 `orcaforcubicon-unified-build-plan` 기준):
Phase 1(스캐폴딩)·2+3(브랜딩+프로파일+splash)·4(GUI 패치: 우클릭 회전, About 버전)·5(NSIS 패키징) 완료,
**전체 Windows 빌드 검증됨**. 남은 건 Phase 6(macOS DMG).

---

## 2. ⚠️ 미완료 항목 — "버전 및 릴리스노트" (사용자가 지적한 부분)

### 2-1. 버전 번호 불연속 (결정 필요)
- 구 스트림은 **1.1.0 → … → 1.4.0 → 1.4.1** 로 릴리스되어 왔고, 마지막에 `4754a93a`로 **1.4.2→1.4.1 되돌림**.
- 신 저장소 SSOT는 곧바로 **1.5.0** 으로 점프.
- **미결정**: 1.5.0을 "통합 빌드 첫 정식 릴리스"로 확정할지, 아니면 구 스트림과 연속(예: 1.4.2/1.5.0-rc)으로 맞출지.
  - 결정하면 `cubicon/version/cubicon_version.txt` 한 줄만 고치면 전체 빌드에 반영됨(`version.inc`가 `file(STRINGS)`로 읽음).

### 2-2. 릴리스노트가 아직 없음 (신규 작성 필요)
- 신 저장소 `cubicon/`·`installer/` 어디에도 **CHANGELOG / 릴리스노트 파일이 없음**.
- 구 앱에는 인앱 릴리스노트 메커니즘이 있었음: `Dependencies/shared/slic3r/GUI/ReleaseNote.cpp/.hpp` + `resources/tooltip/releasenote.html`. (upstream 2.4.2에도 동일 메커니즘 존재 → 신 저장소 `src/slic3r/GUI/ReleaseNote.*`에 있음.)
- **할 일**:
  1. `cubicon/doc/CHANGELOG.md`(또는 `RELEASE_NOTES.md`) 신설 — 구 스트림 히스토리(1.1.0~1.4.1)를 요약 + 통합빌드 전환 내용을 1.5.0 항목으로 정리.
  2. 1.5.0을 사용자에게 보여줄지 여부에 따라 인앱 릴리스노트(HTML/문자열) 갱신 필요 여부 결정.
- 참고: 구 저장소 버전 커밋 히스토리(릴리스노트 원천):
  ```
  1.4.1  4754a93a  Revert 1.4.2 -> 1.4.1
  1.4.0  f2f00dbe  PLA+ 최대유량 23→8·PA 0.025 활성화
  1.3.9  e109f599  filament/process 프로파일 갱신
  1.3.8  5e843997  PLA filament 추가
  1.3.7  e2965308 / 1.3.3 147b418e / 1.3.2 70537a9a / 1.3.1 49576dac / 1.3.0 ad2fab2f
  1.2.0  998771a7  xCeler-Mini 등록
  1.1.0  c4605c40  xCeler-Plus 머신/프로파일 추가
  ```

---

## 3. ⚠️ 미완료 항목 — per-filament 첫 레이어 속도 기능 미이식

- 구 저장소의 핵심 커스텀 기능(**필라멘트별 첫 레이어 속도/선폭 override**, Process 탭 UI 브리지)이
  **신 저장소 `cubicon/patches/`에 아직 패치로 추출되지 않았음**.
- 현재 신 저장소 패치는 브랜딩·마우스 네비게이션·About 버전 3종뿐:
  ```
  cubicon/patches/0001-branding-and-version.patch
  cubicon/patches/0002-cubicon-default-mouse-navigation.patch
  cubicon/patches/0003-about-dialog-version.patch
  ```
- 구 저장소에서 이 기능은 **이미 main에 병합**되어 `Dependencies/shared/libslic3r/` + `slic3r/GUI/` 소스에 존재. 관련 커밋:
  ```
  383d6ae5  Per-filament first layer speed override (PC filament)
  d24bacf5  Bridge per-filament first layer speed override into Process tab UI
  810b372c  Per-filament first layer line width override; PC max flow 10->4
  4afaba83 / de677f4a / 096e41dd  위 브리지 startup 크래시 수정 3종
  ```
- 설계 근거·구현 상세: 구 저장소 `PER_FILAMENT_FIRST_LAYER_SPEED.md`.
  (전역 스칼라 `initial_layer_speed`라 기존 per-extruder override 경로 재사용 불가 → 커스텀 코드 필요. upstream에도 없음.)
- **할 일**: 위 소스 변경을 upstream 2.4.2 트리에 맞춰 재적용하고 `cubicon/patches/0004-per-filament-first-layer-speed.patch`로 추출.
  파일 경로가 구(`Dependencies/shared/…`) → 신(`src/…`)으로 바뀌므로 라인 오프셋 수동 조정 필요.

---

## 4. 신 저장소 커밋 안 된 변경 (git status: 64개)

- 대부분 `resources/profiles/Cubicon/…`(filament/machine) + `splash_logo*.svg` 갱신 — 구 저장소 최신 프로파일 튜닝을 옮겨온 것으로 보임.
- **할 일**: 이 변경들이 구 저장소 1.4.1 프로파일과 일치하는지 확인 후 커밋. (오버레이 원본은 `cubicon/resources/`에, 이 diff는 빌드 트리 `resources/`에 있으니 어느 쪽이 SSOT인지 확인 — `apply_overlay` 스크립트가 `cubicon/resources/` → `resources/`로 복사하는 구조.)

---

## 5. 사소 정리
- `ORCAFORCUBICON.md`의 "진행 단계" 체크박스가 stale (Phase 2~6 미체크로 표기). 실제로는 2~5 완료 → 갱신 필요.

---

## 6. 새 세션 시작 시 추천 순서
1. **버전 정책 확정**(§2-1) → `cubicon/version/cubicon_version.txt` 확정.
2. **릴리스노트 신설**(§2-2) → `cubicon/doc/CHANGELOG.md`.
3. **per-filament 기능 패치화**(§3) → `0004-*.patch`, `apply_overlay` 후 빌드 검증.
4. **미커밋 프로파일 정리·커밋**(§4).
5. `ORCAFORCUBICON.md` 체크박스 갱신(§5), Phase 6(macOS) 착수.

> 푸시는 HTTPS + gh 헬퍼 사용(SSH 키 권한 없음). 참고 메모리: `hyvision-fork-push-credentials`.
