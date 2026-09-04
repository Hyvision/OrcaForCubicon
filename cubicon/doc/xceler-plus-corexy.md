# xCeler-Plus CoreXY — 별도 제품 라인 분리

xCeler-Plus 가 CoreXY 구동 + AC 베드 히터로 개정되면서, 슬라이서에서 **기존 출하 장비와 구분되는
별도 프린터**로 등록했다. 1.5.3-rc1 / 프로파일 패키지 02.03.07.00.

## 왜 필라멘트 프리셋 추가가 아니라 기기 분리인가

- **기존 고객이 자동으로 보호된다.** 기존 `Cubicon xCeler-Plus 0.4 nozzle` 을 건드리지 않았으므로,
  프로파일 패키지를 업데이트해도 그 고객의 ABS-A100 은 계속 115/105 다. 마이그레이션 코드가 필요 없다.
- **선택이 한 번뿐이다.** 프린터는 설치 시 한 번 고르지만 필라멘트는 출력할 때마다 고른다.
  `ABS-A100` 과 `ABS-A100 (AC)` 를 나란히 두면 매 출력마다 틀릴 기회가 생긴다.
- **베드 히터는 장비 속성이다.** 지금은 A100 만 바뀌었지만 베드 온도 열 전체가 재튜닝 대상이 될 수
  있고, 기기 단위로 잘라두면 그 변화가 이 라인 안에서 흡수된다.

## 무엇이 다른가

| | xCeler-Plus (기존) | xCeler-Plus CoreXY |
|---|---|---|
| 구동 | (기존 구조) | CoreXY (`printer_structure: corexy`) |
| 베드 히터 | 기존 | AC, 성능 향상 |
| ABS-A100 베드 온도 | 115 / 105 | **105 / 100** |
| 그 외 필라멘트 | | 기존과 동일 (미검증) |
| 조형 공간 | 310 × 310 × 310 | 310 × 310 × 310 (동일) |
| 모션 설정 | | **기존 값 그대로 복사 — 검토 필요** |

`printer_structure` 는 `psI3` 일 때만 슬라이싱 동작(스파이럴 베이스, 객체별 출력, 타임랩스)에
영향을 주므로, `corexy` 지정은 표기상 정확하면서 동작 변화는 없다.

## 미결 사항

1. **모션 튜닝** — 가속도·저크를 기존 Plus 에서 그대로 복사했다. CoreXY 는 보통 더 높은 가속을
   허용하므로 실측 후 조정해야 한다. 값 주시면 반영한다.
2. **나머지 필라멘트의 베드 온도** — AC 베드에서 ABS(115/115), ABSk, PC, PA-CF 가 그대로여도
   되는지 검증이 필요하다. A100 만 105/100 으로 내려간 것이 다소 이례적이다.
3. **제품명** — `xCeler-Plus CoreXY` 는 임시다. 고객이 **자기 장비를 보고 어느 쪽인지 판단할 수
   있어야** 한다는 것이 유일한 요구 조건이다. 라벨·시리얼 구간·펌웨어 버전 중 무엇으로 구분되는지
   정해지면 그에 맞춰 이름을 바꾼다. 이름을 바꿀 때는 `machine/`·`process/`·`filament/` 의 파일명과
   각 JSON 의 `name`/`printer_model`/`compatible_printers`/`default_materials`, `Cubicon.json` 의
   4개 목록을 함께 바꿔야 한다 (이미 배포된 뒤라면 기존 이름을 유지하는 편이 안전하다).
4. **커버 이미지** — 기존 Plus 이미지를 복사해 두었다. CoreXY 사진으로 교체 필요
   (`Cubicon xCeler-Plus CoreXY_cover.png`).
5. **릴리즈 노트** — 고객용 시트(`OrcaForCubicon_ReleaseNotes.xlsx`)에 신규 기종 추가 반영 필요.

## 빌드 볼륨 가드로는 오선택을 못 막는다

두 기종의 조형 공간이 310³ 로 같아서 `REQ_X/Y/Z` 가 동일하다. 즉 기존 Plus 용으로 슬라이싱한
A100 파일이 CoreXY 장비에서 그대로 출력된다 (크기 기준으로는 정상).
온도 오선택까지 막으려면 별도 장치가 필요하다 — 예: CoreXY 펌웨어의 `START_PRINT` 에서 베드 온도를
하드웨어 실제 상한으로 클램프. 다만 **프로파일 분리의 대체재가 아니라 안전망**으로만 쓸 것.
슬라이서는 115 를 표시하는데 장비가 105 로 굽는 상태는 원인 추적을 어렵게 하므로, 클램프가 걸리면
로그를 남겨야 한다. → [build-volume-guard-firmware.md](build-volume-guard-firmware.md)

## 추가된 파일 (15개) + Cubicon.json 엔트리 14개

```
machine/Cubicon xCeler-Plus CoreXY.json                 (machine_model)
machine/Cubicon xCeler-Plus CoreXY 0.4 nozzle.json      (machine)
process/cubicon default @Cubicon xCeler-Plus CoreXY 0.4 nozzle.json
filament/<11종> @Cubicon xCeler-Plus CoreXY 0.4 nozzle.json
Cubicon xCeler-Plus CoreXY_cover.png
```

베드 텍스처는 기존 `Cubicon xCeler-I_bed_texture.svg` 를 공유한다 (Plus 와 동일).

## 검증

- **프로파일 무결성** — `Cubicon.json` 의 79개 엔트리 전부가 실제 파일로 해석되고,
  `inherits`/`compatible_printers`/`default_materials` 가 모두 유효.
- **슬라이싱** — 4기종 전부 정상 슬라이싱 + 자기 조형 크기를 `START_PRINT` 로 전달:
  ```bash
  python cubicon/scripts/verify_build_volume_guard.py --exe build/OrcaSlicer/OrcaForCubicon.exe
  ```
- **베드 온도 배관** — 두 온도 세트로 슬라이싱해 G-code 에서 확인:

  | | 초기레이어 (`START_PRINT BED_TEMP`) | 이후 레이어 (`M140`) |
  |---|---|---|
  | 기존 Plus | `BED_TEMP=115` | `M140 S105` |
  | CoreXY | `BED_TEMP=105` | `M140 S100` |

### 어느 베드 타입 키가 실제로 쓰이는가

필라멘트 프로파일은 베드 타입별로 5쌍(`cool_/eng_/hot_/textured_/supertack_plate_temp`)을 갖고 있어서
어느 것이 나가는지 확인이 필요했다. Cubicon 기종은 **비-BBL + `support_multi_bed_types=0`** 이므로
`Plater.cpp:2537` 의 분기를 타고 `Preset::get_default_bed_type()` 이 쓰이는데, 프린터 프로파일에
`default_bed_type` 이 없고 BBL 모델 ID 도 아니므로 **`btPEI` = High Temp Plate** 로 확정된다.
따라서 실제 적용 키는 **`hot_plate_temp` / `hot_plate_temp_initial_layer`** 이고, 오버라이드도 여기에 넣었다.

> CLI 로 슬라이싱하면 Plater 가 없어 `curr_bed_type` 이 기본값 `btPC`(Cool Plate)로 남는다.
> ABS 계열은 Cool Plate 온도가 0 이라 CLI 결과가 GUI 와 달라진다. CLI 로 베드 온도를 확인할 때는
> 설정에 `"curr_bed_type": "High Temp Plate"` 를 넣어 GUI 조건을 재현할 것.
