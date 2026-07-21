# OrcaForCubicon — macOS 빌드·패키징 가이드 (Phase 6)

> Windows 빌드는 완료(Phase 1~5). 이 문서는 **동일한 통합 소스 트리를 macOS(Apple Silicon/Intel)에서
> 빌드하고 OrcaForCubicon 브랜딩 DMG로 패키징**하기 위한 절차다. Mac PC에서 그대로 따라 하면 된다.
> Windows 파이프라인과 1:1 대응한다:
>
> | 단계 | Windows | macOS |
> |---|---|---|
> | 오버레이 적용 | `apply_overlay.ps1` | `apply_overlay.sh` |
> | 원샷 빌드 | `build_win.ps1` | **`build_mac.sh`** (신규) |
> | 패키징 | `package_win.ps1` (NSIS) | **`package_mac.sh`** (DMG, 신규) |

---

## 0. 사전 준비 (한 번만)

```bash
# Xcode Command Line Tools
xcode-select --install

# 빌드 도구 (Homebrew)
brew install cmake ninja git
brew install create-dmg          # DMG 레이아웃용(선택; 없으면 hdiutil 폴백)
```

- 권장 최소 배포 타깃: **macOS 11.3** (`OSX_DEPLOYMENT_TARGET`, 기본값).
- Apple Silicon(M1~)에서는 `arm64`, Intel Mac에서는 `x86_64`가 기본. 둘 다 담으려면 `universal`.
- CMake 4.x를 쓰면 `build_release_macos.sh`가 자동으로 정책 호환 플래그(`CMAKE_POLICY_VERSION_MINIMUM=3.5`)를 넣는다.

---

## 1. 소스 가져오기

```bash
git clone <OrcaForCubicon.git remote> OrcaForCubicon
cd OrcaForCubicon
# 필요 시 업스트림 태그 기준 확인: v2.4.2-base
```

> ⚠️ **커밋된 `src/`·`resources/`는 업스트림 원본(pristine)이다.** Cubicon 커스터마이징은
> `cubicon/patches/*.patch` + `cubicon/resources/*` 로만 존재하며, 빌드 직전 오버레이 적용으로 트리에 반영된다.
> 그래서 clone 직후 트리는 깨끗해야 하고, 오버레이 적용은 clone된 pristine 트리 위에서 이뤄진다.

---

## 2. 한 줄 빌드 + 패키지 (권장)

```bash
# git 업데이트만 되어 있으면 이 한 줄로 앱 빌드 + DMG까지 (arm64 기본)
bash cubicon/scripts/build_mac.sh
#   -a x86_64|universal   아키텍처 (Intel/유니버설)
#   -c                    build/<arch> 정리 후 새로 빌드 (clean, 옵션)
#   -D                    의존성 강제 재빌드 (기본: deps/build/<arch>/OrcaSlicer_dep 있으면 재사용)
#   -P                    DMG 없이 앱만
```

`build_mac.sh`가 매 실행마다 하는 일:
1. `git checkout -- src resources` 후 `apply_overlay.sh` — 오버레이(패치+리소스) 재적용 (pristine에서 결정적 빌드)
2. deps — `deps/build/<arch>/OrcaSlicer_dep`가 없을 때만 빌드 (`-D`로 강제)
3. 슬라이서 빌드 → `build/<arch>/OrcaSlicer/OrcaSlicer.app`
4. `package_mac.sh` — `OrcaForCubicon.app` 리브랜딩 + DMG (`-P`로 생략)

### (참고) 수동 단계로 풀어서 하려면
```bash
git checkout -- src resources
bash cubicon/scripts/apply_overlay.sh
./build_release_macos.sh -d -a arm64      # deps
./build_release_macos.sh -s -a arm64      # slicer -> build/arm64/OrcaSlicer/OrcaSlicer.app
```

---

## 3. 패키징만 따로 (DMG, OrcaForCubicon 브랜딩)

```bash
bash cubicon/scripts/package_mac.sh -a arm64
# -> dist/OrcaForCubicon_1.5.0-rc1_macOS_arm64_<yyyymmdd_HHMMSS>.dmg
```

`package_mac.sh`가 하는 일:
1. `OrcaSlicer.app` → **`OrcaForCubicon.app`** 복사·리브랜딩
   - `Info.plist`의 `CFBundleName`/`CFBundleDisplayName` = `OrcaForCubicon`
   - `CFBundleShortVersionString` = `1.5.0-rc1`(SSOT), `CFBundleVersion` = `1.5.0`(rc 접미사 제거 — Apple은 숫자만 허용)
   - 실행 파일명(`CFBundleExecutable = orca-slicer`)은 그대로 둔다(바이너리 실제 이름).
2. (선택) 코드사이닝 — `CODESIGN_IDENTITY` 환경변수가 있으면 `codesign --deep --options runtime`
3. DMG 생성 — `create-dmg`가 있으면 Applications 드롭 링크 포함 레이아웃, 없으면 `hdiutil` 폴백

> **왜 빌드가 아니라 패키징에서 리브랜딩하나?** 앱 번들 이름 `OrcaSlicer.app`은 `src/CMakeLists.txt`와
> `build_release_macos.sh` 여러 곳에 하드코딩되어 있다. 빌드 단계에서 이름을 바꾸면 업스트림 스크립트
> 경로가 깨지므로, 빌드는 표준 이름으로 두고 패키징에서 한 번에 리브랜딩한다(오버레이 최소화).

---

## 4. 배포용 서명·공증 (외부 배포 시)

Gatekeeper 경고 없이 배포하려면 Apple Developer 인증서로 서명 + 공증(notarization)이 필요하다.

```bash
export CODESIGN_IDENTITY="Developer ID Application: Cubicon (TEAMID)"
bash cubicon/scripts/package_mac.sh -a arm64

# 공증(요약) — 앱 서명 후 DMG를 제출
xcrun notarytool submit dist/OrcaForCubicon_1.5.0-rc1_macOS_arm64.dmg \
  --apple-id <apple-id> --team-id <TEAMID> --password <app-specific-pw> --wait
xcrun stapler staple dist/OrcaForCubicon_1.5.0-rc1_macOS_arm64.dmg
```

내부 검증(RC)만 할 거면 서명·공증 없이 배포하고, 최초 실행 시 **우클릭 → 열기**로 Gatekeeper를 통과시키면 된다.

---

## 5. 버전 SSOT

버전은 `cubicon/version/cubicon_version.txt` **한 줄**이 단일 출처다(현재 `1.5.0-rc1`).
- 빌드 시 `version.inc`가 `file(STRINGS ...)`로 읽어 `CUBI_ORCA_VERSION` 매크로로 주입 → About 창·스플래시·DMG 파일명·Info.plist에 반영.
- 숫자만 허용하는 필드(Info.plist `CFBundleVersion`)는 `package_mac.sh`가 `-rc1` 접미사를 자동 제거(`1.5.0`).
- 정식 배포 시 이 파일을 `1.5.0`(또는 다음 버전)으로 고치기만 하면 전 파이프라인에 반영된다.

---

## 6. 검증 체크리스트

- [ ] `build/<arch>/OrcaSlicer/OrcaSlicer.app` 실행 → 정상 기동
- [ ] **정보(About) 창**에 `OrcaForCubicon` + `1.5.0-rc1 (Orca 2.4.2)` 표기 (splash 외 버전 정보 반영 확인)
- [ ] 3D 뷰 **우클릭 드래그 회전** 동작
- [ ] Cubicon 프린터(xCeler-I/Plus/Mini) 프로파일 로드
- [ ] 필라멘트 override(PC): 필라멘트 탭 "First layer" 그룹 노출 + 슬라이스 시 첫 레이어 속도/선폭 반영
- [ ] `package_mac.sh` 산출 DMG 마운트 → `OrcaForCubicon.app` 아이콘·이름 확인 → /Applications 설치 실행

---

## 7. 알려진 이슈 / 팁

- **의존성 빌드는 오래 걸린다**(수십 분~). 한 번 성공하면 `deps/build/<arch>/OrcaSlicer_dep`가 재사용되므로 이후 `build_mac.sh -s`.
- **Homebrew 경로 충돌**: `build_release_macos.sh`는 `CMAKE_IGNORE_PREFIX_PATH=/opt/local:/usr/local:/opt/homebrew`로 시스템 라이브러리 오염을 막는다. 다른 경로에 라이브러리가 있으면 `-i <prefix>`로 추가 무시.
- **유니버설 바이너리**: `-a universal`은 arm64·x86_64 각각 빌드 후 `lipo`로 합친다(빌드 시간 2배). 배포 단순화가 필요할 때만.
- **오버레이 재적용 실패**: `git apply` 실패 시 트리에 이미 패치가 적용됐거나 업스트림이 드리프트한 것. `git status` 확인 후 `git checkout -- src/`로 pristine 복원 뒤 재시도.
- **업스트림 리베이스 후**: 패치 컨텍스트가 어긋나면 `apply_overlay.sh`가 해당 패치에서 멈춘다. 수동 수선 후 `git diff`로 패치 재추출(`cubicon/patches/000X-*.patch` 갱신).
