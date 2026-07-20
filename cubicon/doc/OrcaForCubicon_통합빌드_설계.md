# OrcaForCubicon 통합 빌드 환경 설계서

> 목표: OrcaSlicer **V2.4.2** 업스트림을 기반으로, Windows/Mac을 **하나의 소스 트리**에서
> 관리·빌드·패키징하고, Cubicon 커스터마이징을 **격리된 오버레이**로 재적용할 수 있는 구조 구축.
>
> 방식: **Fresh(업스트림에서 새로 시작) + 오버레이** — 확정됨
> Mac 커스터마이징: Windows와 동일(플랫폼 빌드 스크립트만 상이) — 전제
> 작성일: 2026-07-20

---

## 1. 현재 상태 요약 (조사 결과)

### 1.1 현 Windows 저장소(`Hyvision/Cubicreator_Orca`) 구조
- 업스트림 Orca의 **CMake 구조가 아님**. 손으로 만든 **Visual Studio 솔루션**(`CubicreatorHS.sln`).
- OrcaSlicer 전체 소스가 `Dependencies/shared/`로 **평탄화 복사**되어 있고, 서브라이브러리마다
  `.vcxproj`를 수동 생성(libslic3r, slic3r GUI, imgui, imguizmo, clipper 등 20여 개).
- 일부 prebuilt 라이브러리를 git(LFS 포함)에 커밋.
- **기반 버전이 낡음**: `SoftFever_VERSION "2.3.1-dev"` / `SLIC3R_VERSION "01.10.01.50"`.
  → 목표 V2.4.2 대비 한 세대 뒤처져 있음.

### 1.2 문제점
- 수동 `.vcxproj`는 업스트림 CMake와 구조가 완전히 달라, 2.3.1 → 2.4.2 업그레이드 시
  신규/삭제/이동된 소스 파일을 전부 프로젝트에 수작업 반영해야 함(릴리스마다 반복).
- Windows(VS 솔루션) / Mac(별도 repo)이 갈라져 있어 커스터마이징을 이중 관리.

### 1.3 Cubicon 커스터마이징 실체 (작고 잘 격리됨 → 오버레이에 유리)
| 범주 | 대상 |
|---|---|
| **제품명/버전** | `libslic3r_version.h`: `SLIC3R_APP_NAME="OrcaForCubicon"`, `SLIC3R_APP_KEY="OrcaForCubicon"`, `SLIC3R_OFFICIAL_NAME="OrcaSlicer"`, `CUBI_ORCA_VERSION="1.4.1"` |
| **C++ 소스 수정** | 아래 §4.2 목록(약 18개 파일, slic3r/GUI + libslic3r) |
| **Cubicon 프로파일** | `resources/profiles/Cubicon.json` + `resources/profiles/Cubicon/`(machine/filament/process + cover·bed 이미지) |
| **Splash** | `resources/images/splash_logo_cubicreator.svg` (+ `GUI_App.cpp`의 로고 로딩 분기) |
| **인스톨러** | `Tools/Installer/`(NSIS `InstallScript.nsi`, `MakePackage.cmd`, `default_profile/OrcaForCubicon_1.4.1`, `CopyRuntime.ps1`) |

---

## 2. 판단 — 왜 Fresh인가

- 업스트림 **OrcaSlicer 2.4.2는 이미 단일 CMake 소스 트리로 Win/Mac/Linux 전부 빌드**한다
  (`build_release.bat`, `build_release_macos.sh`, `BuildLinux.sh`). 사용자가 원하는 "통합 소스"가
  업스트림에 이미 존재함.
- 커스터마이징 실체가 **버전헤더 + 소스 ~18파일 + 리소스 + 인스톨러**로 격리되어 있어,
  업스트림 위에 얇은 패치/오버레이로 재적용 가능.
- 반면 기존 VS 솔루션 개조는 매 업그레이드마다 프로젝트 파일 수작업이 필요 → 유지보수 비용 과다.

**결론: 업스트림 2.4.2를 그대로 fork/clone → 커스터마이징을 격리 오버레이로 재적용한다.**

---

## 3. 목표 통합 저장소 구조

원칙: **업스트림 트리는 최대한 원본 유지**, Cubicon 자산은 별도 디렉터리 + 최소 소스 패치로 분리.
이렇게 하면 업스트림 태그 리베이스 시 충돌을 최소화한다.

```
Cubicreator_Orca/                      # 단일 통합 repo (Win/Mac/Linux)
├─ (업스트림 OrcaSlicer 2.4.2 트리 그대로)
│   ├─ src/                            # CMake 소스 (평탄화 X, 업스트림 원본 경로)
│   ├─ resources/                      # 업스트림 리소스
│   ├─ deps/                           # 의존성 빌드 스크립트 (prebuilt 커밋 X)
│   ├─ version.inc                     # ★ 제품명/버전 진입점 (오버레이 대상)
│   ├─ build_release.bat               # Windows 빌드
│   ├─ build_release_macos.sh          # macOS 빌드
│   └─ CMakeLists.txt
│
├─ cubicon/                            # ★ Cubicon 오버레이 루트 (신규, 우리 자산만)
│   ├─ patches/                        # 업스트림 소스에 적용할 git patch (§4.2)
│   │   └─ 0001-branding-and-version.patch ...
│   ├─ resources/                      # 리소스 오버레이 (덮어쓰기 복사)
│   │   ├─ profiles/Cubicon.json
│   │   ├─ profiles/Cubicon/…
│   │   └─ images/splash_logo_cubicreator.svg
│   ├─ branding/                       # 아이콘(.ico/.icns), splash 배경 등
│   └─ version/
│       └─ cubicon_version.txt         # CUBI_ORCA_VERSION 단일 출처(SSOT)
│
├─ installer/                          # ★ 패키징 (기존 Tools/Installer 승계·정리)
│   ├─ windows/  (NSIS: InstallScript.nsi, MakePackage.cmd, CopyRuntime.ps1, nsis_plugin, redist)
│   ├─ macos/    (DMG 생성 스크립트/배경)
│   └─ default_profile/OrcaForCubicon_x.y.z/
│
├─ scripts/                            # ★ 통합 자동화
│   ├─ apply_overlay.(ps1|sh)          # patches + resources 오버레이 적용
│   ├─ set_version.(ps1|sh)            # version.inc + cubicon_version.txt 동기화
│   ├─ build_win.ps1 / build_mac.sh    # 빌드 래퍼
│   └─ package_win.ps1 / package_mac.sh
│
├─ .github/workflows/                  # (선택) CI: Win/Mac 매트릭스 빌드·패키징
└─ doc/                                # 설계·릴리스 노트
```

**핵심 아이디어**
1. 업스트림 소스는 건드리지 않는 것이 이상적이나, 불가피한 소스 변경은 `cubicon/patches/`의
   git patch로 관리(원본에 인라인 수정하지 않음 → 리베이스 시 patch만 재적용/수선).
2. 리소스·브랜딩은 **덮어쓰기 오버레이**(빌드 전 `apply_overlay`로 복사) → 업스트림 diff 없음.
3. 버전은 `cubicon/version/cubicon_version.txt` **단일 출처** → `version.inc`와 인스톨러가 참조.

---

## 4. 커스터마이징 오버레이 카탈로그

### 4.1 브랜딩·버전 (patch: `0001-branding-and-version`)
업스트림은 루트 `version.inc`에서 `SLIC3R_APP_NAME` / `SLIC3R_APP_KEY` / `SoftFever_VERSION` 등을
정의하고, CMake가 `libslic3r_version.h.in` → `libslic3r_version.h`를 생성한다.
- `version.inc`: `SLIC3R_APP_NAME → "OrcaForCubicon"`, `SLIC3R_APP_KEY → "OrcaForCubicon"`,
  `SLIC3R_OFFICIAL_NAME → "OrcaSlicer"` 유지.
- `libslic3r_version.h.in`에 `CUBI_ORCA_VERSION` 매크로 추가(값은 `cubicon_version.txt`에서 주입).

### 4.2 소스 코드 패치 대상 (현 2.3.1 기준 → 2.4.2에서 의미 기반 재적용)
> 아래는 현재 fork에서 `cubicon/CUBI_ORCA/ORCA_FOR_CUBICON`을 참조하는 파일 전수.
> 2.4.2에서 함수 위치가 바뀔 수 있으므로 patch 적용 실패 시 수작업 재적용 필요.

**slic3r/GUI**
- `AboutDialog.cpp` — 버전 표시(`CUBI_ORCA_VERSION`), "Copyright(C) 2025 Cubicon".
- `GUI_App.cpp` — splash 로고 분기, 버전 표시/업데이트 체크에 `CUBI_ORCA_VERSION` 사용.
- `Plater.cpp`, `Tab.cpp/.hpp`, `CreatePresetsDialog.cpp`, `GCodeViewer.cpp`,
  `NetworkTestDialog.cpp` — 브랜드/버전 문자열·소소한 분기.
- `Utils/Http.cpp`, `Utils/PresetUpdater.cpp` — 프리셋 업데이트/네트워크 경로 관련.

**libslic3r**
- `libslic3r.h`, `libslic3r_version.h` — 빌드 ID/버전(§4.1로 흡수).
- `Preset.cpp`, `PresetBundle.cpp`, `PlaceholderParser.cpp`, `PrintBase.cpp`,
  `Format/bbs_3mf.cpp`, `utils.cpp` — 프로파일/메타 관련 Cubicon 분기.

> 실행 팁: fresh 시 각 파일에 대해 "무엇을·왜 바꿨는지"를 patch 헤더 주석으로 남겨,
> 다음 업스트림 리베이스 때 의도를 잃지 않게 한다.

### 4.5 Cubicon 프로파일 확장 가이드 (신규 프린터·필라멘트·Process 추가)

Cubicon 프로파일은 `resources/profiles/` 아래 **벤더 인덱스 1개 + 하위 json 트리**로 구성된다.
모든 하위 json은 **반드시 벤더 인덱스에 등록**되어야 앱에 노출된다.

```
resources/profiles/
├─ Cubicon.json                 # ★ 벤더 인덱스(SSOT): 아래 3개 목록에 등록해야 로드됨
│   ├─ machine_model_list[]     #   {name, sub_path}
│   ├─ process_list[]           #   {name, sub_path}
│   └─ filament_list[]          #   {name, sub_path}
└─ Cubicon/
   ├─ machine/                  # machine_model(모델 정의) + machine(설정) 2종
   ├─ filament/                 # @base + 프린터별 변형(@…nozzle)
   ├─ process/                  # 공통 @base + 프린터별 default(@…nozzle)
   ├─ <프린터>_cover.png         # 프린터 카드 이미지
   └─ <프린터>_bed_texture.svg   # 베드 텍스처
```

**상속 규칙**: `inherits`로 부모 프리셋명을 참조, `from:"system"`, `instantiation:"true"`,
`compatible_printers`로 노출 대상 프린터를 지정. 프린터별 변형은 `@base`를 상속해 차이만 덮어쓴다.

#### (A) 신규 프린터 추가 — 예: `Cubicon xCeler-II`
1. **machine_model** 파일 생성 `machine/Cubicon xCeler-II.json`
   ```json
   {
     "type": "machine_model", "name": "Cubicon xCeler-II",
     "nozzle_diameter": "0.4",
     "bed_texture": "Cubicon xCeler-II_bed_texture.svg",
     "family": "Cubicon", "machine_tech": "FFF",
     "default_materials": "Cubicon PLA @Cubicon xCeler-II"
   }
   ```
2. **machine 설정** 파일 생성 `machine/Cubicon xCeler-II 0.4 nozzle.json`
   - 기존 `Cubicon xCeler-I 0.4 nozzle.json`을 복제 → `name`을 `Cubicon xCeler-II 0.4 nozzle`로,
     `inherits:"fdm_machine_common"`, `default_filament_profile`/`default_print_profile`을
     신규 프린터명 기준으로 수정. 베드 크기·프린터블 영역·시작/종료 G-code 등 하드웨어 값 조정.
3. **이미지 추가**: `Cubicon xCeler-II_cover.png`, `Cubicon xCeler-II_bed_texture.svg` (profile 루트).
4. **필라멘트/Process 변형 생성**: 아래 (B)·(C)로 이 프린터용 `@Cubicon xCeler-II 0.4 nozzle`
   변형들을 추가(최소 default 필라멘트/Process 1종은 있어야 `default_materials`/`default_print_profile`가 유효).
5. **벤더 인덱스 등록**: `Cubicon.json`의 `machine_model_list`에
   `{"name":"Cubicon xCeler-II","sub_path":"machine/Cubicon xCeler-II.json"}` 추가.
   (machine 설정 파일은 machine_model_list가 아니라 자동 로드 — 단, process/filament 변형은 각 list에 등록 필요)

#### (B) 전용 필라멘트 추가 — 예: `Cubicon TPU`
1. **@base 생성** `filament/Cubicon TPU @base.json`
   - `type:"filament"`, `instantiation:"true"`, `from:"system"`, `name:"Cubicon TPU @base"`,
     고유 `filament_id`(중복 금지, 예 `PCbcTPU1`), `filament_type:["TPU"]`,
     온도·냉각·리트랙션 등 소재 특성값, `compatible_printers`에 지원 프린터 나열.
   - 필요 시 업스트림 공통 프리셋(`fdm_filament_common` 등)을 `inherits`로 참조.
2. **프린터별 변형 생성** `filament/Cubicon TPU @Cubicon xCeler-I 0.4 nozzle.json`
   ```json
   {
     "type":"filament","instantiation":"true","from":"system","version":"1.0.0.0",
     "name":"Cubicon TPU @Cubicon xCeler-I 0.4 nozzle",
     "compatible_printers":["Cubicon xCeler-I 0.4 nozzle"],
     "inherits":"Cubicon TPU @base"
   }
   ```
   프린터별로 flow/속도 차이가 있으면 이 변형에서만 덮어쓴다. 지원 프린터 수만큼 반복.
3. **벤더 인덱스 등록**: `filament_list`에 `@base`와 모든 프린터 변형을 각각 `{name, sub_path}`로 추가.

> 참고: `filament_id`는 전역 고유 식별자이므로 기존 값과 절대 겹치지 않게 부여할 것.
> 신규 소재가 특정 프린터의 `default_materials`가 되어야 하면 (A)-1의 `default_materials`에 반영.

#### (C) 전용 Process(프린트 설정) 추가
1. **공통 base** `process/cubicon common @base.json`에 브랜드 공통 기본값을 둔다(이미 존재).
   새 계열 Process가 필요하면 별도 `@base`(예 `cubicon fast @base.json`)를 만들고 위 공통을 상속.
2. **프린터별 default 생성** `process/cubicon default @Cubicon xCeler-II 0.4 nozzle.json`
   ```json
   {
     "version":"1.0.0.0","type":"process","instantiation":"true",
     "inherits":"cubicon common @base",
     "name":"cubicon default @Cubicon xCeler-II 0.4 nozzle",
     "print_settings_id":"cubicon default @Cubicon xCeler-II 0.4 nozzle",
     "compatible_printers":["Cubicon xCeler-II 0.4 nozzle"]
   }
   ```
   레이어 높이·속도·벽 두께 등 프린터별 차이는 이 파일에서 덮어쓴다.
3. **벤더 인덱스 등록**: `process_list`에 추가. 프린터의 기본 Process로 쓰려면 machine 설정의
   `default_print_profile`에 이 이름을 지정.

#### (D) 오버레이·검증 체크리스트
- [ ] 위 파일들은 통합 repo에서 `cubicon/resources/profiles/`에 두고 `apply_overlay`로 복사(§3).
- [ ] `Cubicon.json`의 `version` 필드를 올려 사용자 측 프로파일 자동 업데이트를 유도.
- [ ] `inherits`/`compatible_printers`/`name`이 서로 정확히 일치(오타 시 조용히 미노출).
- [ ] `filament_id`·`print_settings_id` 고유성 확인.
- [ ] JSON 유효성 검사 후 앱 실행 → 프린터 선택 마법사에 신규 프린터/필라멘트/Process 노출 확인.
- [ ] 2.4.2 스키마에서 사라지거나 이름이 바뀐 키가 없는지 로드 로그로 경고 확인(§9).

### 4.3 리소스 오버레이 (patch 아님, 복사)
- `resources/profiles/Cubicon.json` + `resources/profiles/Cubicon/**`
  (machine/filament/process, cover PNG, bed_texture SVG) — 현행 최신본을 SSOT로 승격.
- `resources/images/splash_logo_cubicreator.svg` (필요 시 `splash_logo.svg` 교체).
- 앱 아이콘: `CubicreatorHS.ico`(Win), `.icns`(Mac).

### 4.4 인스톨러/패키징
- Windows: `installer/windows/`에 NSIS 스크립트·`MakePackage.cmd`·`CopyRuntime.ps1` 이관.
- macOS: DMG 생성 스크립트·배경 이미지 이관(현 `Tools/Installer/DMG 파일 만들기*` 참고).
- `default_profile/OrcaForCubicon_x.y.z`: 버전 폴더명을 `set_version` 스크립트가 자동 갱신.

---

## 5. 버전 관리 설계
- **단일 출처**: `cubicon/version/cubicon_version.txt` (예: `1.5.0`).
- `scripts/set_version`가 다음을 동기화:
  - `version.inc`의 앱명/버전 필드,
  - `libslic3r_version.h.in`의 `CUBI_ORCA_VERSION`,
  - 인스톨러 산출물 이름(`OrcaForCubicon Setup Vx.y.z(Rn)_YYYYMMDD`),
  - `default_profile` 폴더명.
- git 태그 규칙: `V<cubicon>_orca<upstream>` 예) `V1.5.0_orca2.4.2` — 어느 Cubicon 버전이
  어느 업스트림 위에 올라갔는지 추적.

---

## 6. 빌드 파이프라인 (단일 소스)
- **Windows**: `deps` 빌드 → `scripts/apply_overlay.ps1` → `build_release.bat` → `package_win.ps1`(NSIS).
- **macOS**: `deps` 빌드 → `scripts/apply_overlay.sh` → `build_release_macos.sh` → `package_mac.sh`(DMG).
- 공통: 오버레이 적용은 빌드 직전 1회. CI(선택)에서 Win/Mac 매트릭스로 자동화 가능.
- prebuilt 라이브러리는 git에 커밋하지 않고 업스트림 `deps` 방식으로 빌드(저장소 경량화·재현성).

---

## 7. 업스트림 업데이트(리베이스) 워크플로우
향후 2.4.3 / 2.5.x 등으로 올릴 때:
1. `upstream` 원격의 새 태그를 통합 repo에 머지/체크아웃.
2. `cubicon/patches/*.patch`를 `git apply --3way`로 재적용, 충돌 파일만 수작업 수선.
3. 리소스 오버레이는 그대로 복사(충돌 없음). 프로파일 스키마 변경 시에만 갱신.
4. 빌드·스모크 테스트 → 새 태그(`V<n>_orca<m>`) 발행.

→ 커스터마이징이 patch+overlay로 격리되어 있어, 업그레이드가 "충돌 수선"으로 단순화됨.

---

## 8. 마이그레이션 단계별 실행 계획
| 단계 | 작업 | 산출물 |
|---|---|---|
| 0 | 본 설계 확정 | (이 문서) |
| 1 | 통합 repo 뼈대 생성: 업스트림 2.4.2 clone + `cubicon/`,`installer/`,`scripts/` 골격 | 빈 오버레이 골격 |
| 2 | 브랜딩·버전 오버레이(§4.1) 적용, 빌드 통과 확인 | "OrcaForCubicon" 이름/버전 반영 빌드 |
| 3 | 리소스 오버레이(§4.3): Cubicon 프로파일·splash 이식 | 프로파일·스플래시 반영 |
| 4 | 소스 패치(§4.2) 의미 기반 재적용 | GUI/문자열/분기 반영 |
| 5 | Windows 패키징(NSIS) 이관·검증 | `OrcaForCubicon Setup Vx.y.z.exe` |
| 6 | macOS 빌드·DMG 검증 | `OrcaForCubicon.dmg` |
| 7 | (선택) CI 매트릭스, 리베이스 스크립트 정비 | 자동화 |

---

## 9. 리스크·확인 필요 사항
- **2.4.2에서 함수/파일 위치 변동**: §4.2 patch 일부는 수작업 재적용 필요(예상 범위 내).
- **프로파일 스키마 차이**: 2.3.1 프로파일 JSON이 2.4.2에서 경고 없이 로드되는지 검증 필요.
- **Mac 서명/공증(notarization)**: DMG 배포 시 Apple 서명 절차 확인 필요(별도 자격 증명).
- **기존 대용량 산출물**: 현 repo의 `.exe`/prebuilt lib/LFS 자산은 신규 통합 repo에 가져가지 않음
  (릴리스 아티팩트로 분리 관리 권장).
- **Mac 전용 차이**: "동일 커스터마이징" 전제 — 추후 Mac repo 실물 확인 시 서명/아이콘/DMG만 반영.

---

## 부록 A. 현재 커스터마이징 파일 전수 (2.3.1 fork 기준)
```
libslic3r/libslic3r.h, libslic3r_version.h, Preset.cpp, PresetBundle.cpp,
libslic3r/PlaceholderParser.cpp, PrintBase.cpp, utils.cpp, Format/bbs_3mf.cpp
slic3r/GUI/AboutDialog.cpp, GUI_App.cpp, Plater.cpp, Tab.cpp, Tab.hpp,
        CreatePresetsDialog.cpp, GCodeViewer.cpp, NetworkTestDialog.cpp
slic3r/Utils/Http.cpp, PresetUpdater.cpp
resources/profiles/Cubicon.json (+ Cubicon/ 전체)
resources/images/splash_logo_cubicreator.svg
Tools/Installer/ (NSIS, MakePackage.cmd, CopyRuntime.ps1, default_profile/OrcaForCubicon_1.4.1)
```
