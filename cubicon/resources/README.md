# cubicon/resources/

빌드 직전 업스트림 `resources/` 위로 **덮어쓰기 복사**되는 리소스 오버레이입니다.
(patch가 아니라 파일 복사이므로 업스트림 diff가 발생하지 않습니다.)

```
resources/
├─ profiles/
│  ├─ Cubicon.json          # 벤더 인덱스 (machine_model_list / process_list / filament_list)
│  └─ Cubicon/              # machine, filament, process, cover PNG, bed_texture SVG
└─ images/
   └─ splash_logo_cubicreator.svg
```

## 프로파일 확장 (신규 프린터/필라멘트/Process)
`cubicon/doc/OrcaForCubicon_통합빌드_설계.md` §4.5 참고. 요점:
- 모든 하위 json은 `Cubicon.json`의 해당 목록에 `{name, sub_path}`로 **등록해야 노출**됨.
- 프린터별 변형은 `@base`를 `inherits`하고 `compatible_printers`로 대상 지정.
- `filament_id` / `print_settings_id`는 전역 고유.
- 변경 후 `Cubicon.json`의 `version` 필드를 올려 사용자 자동 업데이트 유도.

> Phase 3에서 최신 프로파일(현 `Cubicreator_Orca.git`의 v1.4.x 프로덕션 프로파일)을 이식하며 채워집니다.
