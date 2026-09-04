# 기종별 출력 제한 (Build volume guard)

슬라이싱한 기종보다 **작은** 프린터에서 그 G-code 가 출력되지 않도록 막는 기능.

| 파일을 만든 기종 | 요구 크기 | Mini 에서 | xCeler-I 에서 | Plus 계열에서 |
|---|---|---|---|---|
| xCeler-Mini | 150 × 150 × 150 | 허용 | 허용 | 허용 |
| xCeler-I | 250 × 250 × 290 | 차단 | 허용 | 허용 |
| xCeler-Plus | 310 × 310 × 310 | 차단 | 차단 | 허용 |
| xCeler-Plus CoreXY | 310 × 310 × 310 | 차단 | 차단 | 허용 |

xCeler-Plus 와 xCeler-Plus CoreXY 는 조형 공간이 같아서 **이 가드로는 서로 구분되지 않는다.**
두 기종은 ABS-A100 베드 온도가 다르므로, 그 오선택은 별도로 다뤄야 한다.
→ [xceler-plus-corexy.md](xceler-plus-corexy.md)

조형 공간이 `Mini ⊂ xCeler-I ⊂ Plus` 로 완전히 포함되므로 **치수 비교 한 번**으로 위 표가 그대로 성립한다.
모델명 목록을 관리할 필요가 없고, 기종이 추가돼도 규칙을 고칠 필요가 없다.

## 1. 슬라이서 쪽 — 반영 완료 (1.5.3-rc0), 출력 검증 완료

4기종의 `machine_start_gcode` 가 요구 크기를 `START_PRINT` 파라미터로 전달한다.

```
START_PRINT EXTRUDER_TEMP=[nozzle_temperature_initial_layer] BED_TEMP=[bed_temperature_initial_layer_single] REQ_X={print_bed_size[0]} REQ_Y={print_bed_size[1]} REQ_Z={printable_height}
```

`print_bed_size` 는 `GCode.cpp:2911` 에서 설정되고 시작 G-code 는 `3118` 에서 처리되므로
순서상 사용 가능하다. 슬라이서 코드 수정은 필요 없다.

### 실제 생성된 G-code (4기종 슬라이싱 확인)

20 mm 정육면체를 기종별 프로파일로 슬라이싱했을 때 파일 선두에 나온 `START_PRINT` 줄:

```gcode
START_PRINT EXTRUDER_TEMP=200 BED_TEMP=35 REQ_X=150 REQ_Y=150 REQ_Z=150   ; xCeler-Mini
START_PRINT EXTRUDER_TEMP=200 BED_TEMP=35 REQ_X=250 REQ_Y=250 REQ_Z=290   ; xCeler-I
START_PRINT EXTRUDER_TEMP=200 BED_TEMP=35 REQ_X=310 REQ_Y=310 REQ_Z=310   ; xCeler-Plus
START_PRINT EXTRUDER_TEMP=200 BED_TEMP=35 REQ_X=310 REQ_Y=310 REQ_Z=310   ; xCeler-Plus CoreXY
```

- 값은 **소수점 없이 정수**로 나온다 (`310`, `310.000000` 이 아님).
- 위치는 파일 선두(헤더 직후, 첫 이동 명령 이전)라서 매크로에서 가장 먼저 판정된다.
- `bed_exclude_area` 는 `print_bed_size` 에 영향을 주지 않는다 — 베드 전체 크기가 나간다.

### 검증 재실행 방법

프로파일의 조형 크기나 시작 G-code 를 건드린 뒤에는 다시 돌린다.

```bash
python cubicon/scripts/verify_build_volume_guard.py --exe build/OrcaSlicer/OrcaForCubicon.exe
```

4기종을 슬라이싱해 `REQ_*` 값이 표의 요구 크기와 같은지 비교하고 PASS/FAIL 을 낸다.
CLI 는 프리셋의 `inherits` 를 해석하지 못하므로 스크립트가 상속을 펼친 임시 JSON 을 만들어 넘긴다.

## 2. 프린터 쪽 — 미반영 (펌웨어 팀 작업 필요)

이 단계가 없으면 파라미터는 그냥 무시되고 **동작은 종전과 같다.**
매크로 전문·설정 값·시험 항목·배포 순서는 별도 문서로 정리했다:

> **[build-volume-guard-firmware.md](build-volume-guard-firmware.md)** — 펌웨어(Klipper) 작업 문서

요약하면 `printer.cfg` 의 `START_PRINT` 매크로 맨 앞에서 `params.REQ_*` 와 그 장비의
조형 크기를 비교해, 파일이 더 큰 기종용이면 `action_raise_error` 로 출력을 중단시킨다.

## 3. 지켜야 할 조건

- **기본값은 반드시 "허용"** — `default(0)` 을 쓴 이유. 파라미터가 없는 기존 G-code 파일이
  전부 막히면 안 된다. 기본값을 차단으로 두면 과거 파일이 모두 출력 불가가 된다.
- **배포 순서는 자유** — Klipper 매크로는 자신이 쓰지 않는 파라미터를 무시하므로,
  슬라이서를 먼저 배포해도 구형 펌웨어 장비에서 오류가 나지 않는다.
- **여유값 0.5 mm** — 슬라이서 프로파일의 조형 크기와 펌웨어가 아는 조형 크기가
  소수점에서 미세하게 다를 수 있어 둔 값.
- **판정 기준은 "슬라이싱한 기종의 조형 크기"** 이지 출력물의 실제 크기가 아니다.
  작은 부품이라도 Plus 로 슬라이싱했으면 Mini 에서는 차단된다. 가감속·시작 매크로·
  베드 메시가 기종별로 다르므로 이 보수적 기준을 택했다.
  실제 출력물 크기 기준으로 완화하려면 `print_bed_size` 대신
  `first_layer_print_max` 를 보내면 되지만, 기종별 속도 설정이 그대로 따라가므로
  품질 보증이 어려워진다.
