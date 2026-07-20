# cubicon/ — OrcaForCubicon 오버레이 루트

이 디렉터리는 업스트림 OrcaSlicer 트리 위에 얹는 **Cubicon 전용 커스터마이징**을 모아둔 곳입니다.
업스트림 소스(`src/`, `resources/`, `deps/` 등)는 최대한 원본을 유지하고, Cubicon 자산은 전부
여기(그리고 최상위 `installer/`)에 격리하여 업스트림 업그레이드(리베이스) 충돌을 최소화합니다.

기반 업스트림 버전: **OrcaSlicer v2.4.2** (태그 `v2.4.2-base`)

## 구조
```
cubicon/
├─ patches/        업스트림 소스에 적용할 git patch (브랜딩/버전/GUI 문자열 등)
├─ resources/      리소스 오버레이 (빌드 전 resources/ 로 복사)
│  ├─ profiles/    Cubicon.json + Cubicon/ (machine/filament/process, cover·bed 이미지)
│  └─ images/      splash_logo_cubicreator.svg 등
├─ branding/       앱 아이콘(.ico/.icns), splash 배경 등
├─ version/        cubicon_version.txt (CUBI_ORCA_VERSION 단일 출처)
├─ scripts/        apply_overlay / set_version / build / package 자동화
└─ doc/            설계서·릴리스 노트
```

## 빌드 흐름 (요약)
1. `deps` 빌드 (업스트림 방식)
2. `cubicon/scripts/apply_overlay.(ps1|sh)` — patches + resources 오버레이 적용
3. `build_release.bat`(Win) / `build_release_macos.sh`(Mac)
4. `cubicon/scripts/package_*.（ps1|sh)` — NSIS(Win) / DMG(Mac)

자세한 내용: `cubicon/doc/OrcaForCubicon_통합빌드_설계.md`

## 상태 (Phase 1 — 스캐폴딩)
- [x] 업스트림 v2.4.2 기반 트리
- [x] 오버레이 디렉터리 골격
- [ ] 브랜딩·버전 오버레이 (Phase 2)
- [ ] Cubicon 프로파일 이식 (Phase 3)
- [ ] 소스 패치 재적용 (Phase 4)
- [ ] Windows 패키징 (Phase 5)
- [ ] macOS 빌드·DMG (Phase 6)
