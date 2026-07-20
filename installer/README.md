# installer/ — OrcaForCubicon 패키징

플랫폼별 설치 패키지 생성 자산. 기존 `Cubicreator_Orca.git/Tools/Installer`에서 이관·정리합니다.

```
installer/
├─ windows/          NSIS (InstallScript.nsi, MakePackage.cmd), CopyRuntime.ps1, nsis_plugin, redist
├─ macos/            DMG 생성 스크립트 / 배경 이미지
└─ default_profile/  OrcaForCubicon_x.y.z  (버전 폴더명은 set_version 이 자동 갱신)
```

산출물 이름 규칙: `OrcaForCubicon Setup Vx.y.z(Rn)_YYYYMMDD.exe` (Windows), `OrcaForCubicon.dmg` (macOS).
버전은 `cubicon/version/cubicon_version.txt` 단일 출처를 따릅니다.

> Phase 5(Win)/Phase 6(Mac)에서 실제 스크립트를 이관하며 채워집니다.
