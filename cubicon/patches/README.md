# cubicon/patches/

업스트림 소스에 적용해야 하는 Cubicon 변경을 **git patch**로 관리합니다.
인라인으로 업스트림 파일을 직접 수정하지 않고 여기서 patch로 관리하면, 업스트림 업그레이드 시
`git apply --3way`로 재적용하고 충돌 파일만 수선하면 됩니다.

## 명명 규칙
```
0001-branding-and-version.patch      # version.inc / libslic3r_version.h.in (제품명·CUBI_ORCA_VERSION)
0002-splash-logo.patch               # GUI_App.cpp splash 로고 분기
0003-about-copyright.patch           # AboutDialog.cpp (Copyright Cubicon, 버전 표시)
00xx-....patch                       # 이하 §4.2 목록
```

각 patch 헤더 주석에 **무엇을·왜** 바꿨는지 남길 것 (다음 리베이스 때 의도 보존).

## 생성/적용
- 생성: 업스트림 원본 대비 변경 후 `git diff > cubicon/patches/00xx-....patch`
- 적용: `cubicon/scripts/apply_overlay`가 순서대로 `git apply --3way` 실행

> Phase 4에서 2.3.1 fork(`Cubicreator_Orca.git`)의 변경을 의미 기반으로 재적용하며 채워집니다.
