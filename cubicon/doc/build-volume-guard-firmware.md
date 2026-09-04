# 기종별 출력 제한 — 펌웨어(Klipper) 작업 문서

슬라이서 쪽은 1.5.3-rc0 에서 끝났고 실제 G-code 출력까지 확인했다
(→ [build-volume-guard.md](build-volume-guard.md)).
이 문서는 **남은 절반, 프린터에서의 판정/차단**을 어떻게 넣는지 정리한 것이다.

이 작업이 들어가기 전까지 슬라이서가 보내는 파라미터는 무시되므로 **동작은 종전과 같다.**

---

## 1. 슬라이서가 보내는 것 (확정된 인터페이스)

파일 선두 `START_PRINT` 줄에 요구 조형 크기 3개가 붙는다.

```gcode
START_PRINT EXTRUDER_TEMP=200 BED_TEMP=35 REQ_X=310 REQ_Y=310 REQ_Z=310
```

| 파라미터 | 뜻 | 예시 | 비고 |
|---|---|---|---|
| `REQ_X` | 슬라이싱한 기종의 베드 X (mm) | `150` `250` `310` | 정수로 나옴 |
| `REQ_Y` | 슬라이싱한 기종의 베드 Y (mm) | `150` `250` `310` | 정수로 나옴 |
| `REQ_Z` | 슬라이싱한 기종의 최대 높이 (mm) | `150` `290` `310` | 정수로 나옴 |

- **출력물 크기가 아니라 "슬라이싱한 기종의 조형 크기"** 다. 20 mm 부품이라도 Plus 로
  슬라이싱했으면 `REQ=310×310×310` 이 붙는다.
- 값은 현재 정수로 나오지만, 사용자가 프로파일 조형 크기를 바꾸면 소수가 될 수 있으므로
  매크로에서는 **반드시 `|float`** 로 받는다.
- **파라미터가 아예 없는 파일이 존재한다** — 1.5.2 이하로 만든 기존 G-code 전부.
  이 경우는 무조건 허용해야 한다.

## 2. 판정 규칙

| 파일을 만든 기종 | REQ | Mini(150³) | xCeler-I(250×250×290) | Plus(310³) |
|---|---|---|---|---|
| xCeler-Mini | 150 150 150 | 허용 | 허용 | 허용 |
| xCeler-I | 250 250 290 | **차단** | 허용 | 허용 |
| xCeler-Plus | 310 310 310 | **차단** | **차단** | 허용 |
| xCeler-Plus CoreXY | 310 310 310 | **차단** | **차단** | 허용 (Plus 와 구분 불가) |
| 1.5.2 이하 (REQ 없음) | — | 허용 | 허용 | 허용 |

조형 공간이 `Mini ⊂ xCeler-I ⊂ Plus` 로 완전히 포함되므로 **축별 치수 비교 한 번**이면
위 표가 그대로 성립한다. 모델명 목록을 관리할 필요가 없다.

```
차단 조건:  REQ_X > MAX_X + 0.5  또는  REQ_Y > MAX_Y + 0.5  또는  REQ_Z > MAX_Z + 0.5
```

여유값 0.5 mm 는 슬라이서 프로파일 값과 펌웨어가 아는 값이 소수점에서 어긋나는 경우를
흡수하기 위한 것이다.

## 3. printer.cfg 수정

### 3-1. 기종의 조형 크기를 선언한다 (기종별로 값이 다름)

`printer.toolhead.axis_maximum` 을 그대로 쓰지 말고 **별도 변수로 명시**할 것을 권한다.
`axis_maximum` 은 킨매틱 한계라서 베드 실제 크기와 다를 수 있고(오프셋·프로브 여유 등),
비교 기준은 "슬라이서 프로파일에 적힌 조형 크기"와 같은 숫자여야 하기 때문이다.

```ini
# 기종별로 이 블록의 값만 바꾼다.
#   xCeler-Mini        : 150 / 150 / 150
#   xCeler-I           : 250 / 250 / 290
#   xCeler-Plus        : 310 / 310 / 310
#   xCeler-Plus CoreXY : 310 / 310 / 310
[gcode_macro _BUILD_VOLUME]
variable_max_x: 310
variable_max_y: 310
variable_max_z: 310
variable_tolerance: 0.5
variable_enforce: 1          # 1 = 차단, 0 = 경고만 (배포 1단계용)
gcode:
```

`gcode:` 는 빈 줄로 둔다 — 변수 보관용 매크로다.

### 3-2. START_PRINT 맨 앞에 판정을 넣는다

가열·호밍보다 **먼저** 와야 한다. 뒤에 두면 히터가 올라간 뒤에 중단돼 시간과 전력이 낭비된다.

```ini
[gcode_macro START_PRINT]
gcode:
    # ---- 조형 공간 확인 (파라미터가 없으면 통과) ----
    {% set bv = printer["gcode_macro _BUILD_VOLUME"] %}
    {% set req_x = params.REQ_X|default(0)|float %}
    {% set req_y = params.REQ_Y|default(0)|float %}
    {% set req_z = params.REQ_Z|default(0)|float %}
    {% set tol = bv.tolerance|float %}
    {% if req_x > bv.max_x|float + tol
       or req_y > bv.max_y|float + tol
       or req_z > bv.max_z|float + tol %}
        {% set msg = "Build volume mismatch: file needs "
             ~ req_x|int ~ "x" ~ req_y|int ~ "x" ~ req_z|int ~ " mm, this printer is "
             ~ bv.max_x|int ~ "x" ~ bv.max_y|int ~ "x" ~ bv.max_z|int
             ~ " mm. Re-slice for this model." %}
        {% if bv.enforce|int == 1 %}
            { action_raise_error(msg) }
        {% else %}
            RESPOND TYPE=error MSG="{msg}"
        {% endif %}
    {% endif %}
    # ---- 이하 기존 START_PRINT 내용 ----
    ...
```

### 3-3. 문법상 주의할 점

- **`action_raise_error` 는 매크로가 평가되는 시점에 즉시 예외를 던진다.** 뒤쪽 줄은
  실행되지 않고 출력이 중단된다. 프린터가 shutdown 되는 것은 아니라 재출력은 바로 가능하다.
- **문자열은 `~` 로 이어붙인다.** `"...%.0f..." | format(a, b)` 형태는 필터 우선순위가
  `~` 보다 높아서 어느 문자열에 붙는지 헷갈리기 쉽다. `~` + `|int` 조합이 안전하다.
- **메시지는 영문 권장.** Moonraker/Mainsail 은 UTF-8 을 처리하지만 일부 LCD 펌웨어는
  한글을 깨뜨린다. 한글이 필요하면 LCD 표시까지 확인한 뒤 넣는다.
- **`params.REQ_X` 는 없으면 Undefined 이고 `|default(0)` 이 이를 받는다.** 기본값 0 이면
  어떤 장비의 크기보다도 작으므로 항상 통과 — 이것이 레거시 파일 허용의 근거다.
  **기본값을 크게 잡으면 과거 파일이 전부 출력 불가가 되니 절대 바꾸지 말 것.**
- Klipper 는 매크로가 참조하지 않는 파라미터를 무시한다. 그래서 슬라이서를 먼저 배포해도
  구형 펌웨어 장비에서 오류가 나지 않는다.
- `RESPOND` 를 쓰려면 `printer.cfg` 에 `[respond]` 가 있어야 한다. 없다면 경고 단계에서는
  `{ action_respond_info(msg) }` 로 대체한다.

## 4. 시험 항목

3가지 조형 공간 × 3파일 + 레거시. `enforce: 1` 상태에서 확인한다.
xCeler-Plus CoreXY 는 Plus 와 조형 공간이 같아 아래 표의 Plus 행이 그대로 적용된다.

| # | 파일 | 장비 | 기대 결과 |
|---|---|---|---|
| 1 | Mini 로 슬라이싱 | Mini | 정상 출력 |
| 2 | Mini | xCeler-I | 정상 출력 |
| 3 | Mini | Plus | 정상 출력 |
| 4 | xCeler-I | Mini | **차단** + 메시지 표시 |
| 5 | xCeler-I | xCeler-I | 정상 출력 |
| 6 | xCeler-I | Plus | 정상 출력 |
| 7 | Plus | Mini | **차단** |
| 8 | Plus | xCeler-I | **차단** (높이 310 > 290 에서 걸림) |
| 9 | Plus | Plus | 정상 출력 |
| 10 | 1.5.2 이하로 만든 기존 파일 (REQ 없음) | 전 기종 | 정상 출력 (회귀 확인) |
| 11 | 1.5.3 파일 (REQ 있음) | 구형 펌웨어 장비 | 정상 출력 (파라미터 무시) |

확인 포인트

- 차단 시 **히터가 켜지기 전에** 멈추는지.
- 차단 메시지에 요구 크기와 장비 크기가 모두 보이는지.
- 차단 후 프린터가 정상 상태로 남아 다음 출력이 바로 되는지 (shutdown/재시작 불필요).
- 8번은 X·Y 는 통과하고 **Z 에서만** 걸리는 케이스라 축별 비교가 맞는지 확인하는 데 중요하다.

## 5. 배포 순서

1. **슬라이서 먼저** (1.5.3) — 파라미터만 실려 나가고 동작 변화 없음. 이미 준비됨.
2. **펌웨어 1단계 `enforce: 0`** — 경고만 띄우고 출력은 계속. 현장 파일에서 오탐이 없는지
   로그로 확인한다.
3. **펌웨어 2단계 `enforce: 1`** — 실제 차단.

각 기종 이미지에 `_BUILD_VOLUME` 값을 그 기종 값으로 넣는 것을 잊지 말 것.
값이 틀리면 정상 파일이 차단되거나(작게 넣은 경우) 기능이 무력화된다(크게 넣은 경우).

## 6. 나중에 논의할 것

- **실제 출력물 크기 기준으로 완화**: 슬라이서에서 `print_bed_size` 대신
  `first_layer_print_max` 를 보내면 "작은 부품은 어느 기종에서든 출력" 이 가능해진다.
  다만 기종별 속도·가감속 설정이 그대로 따라가므로 품질 보증이 어려워 현재는 채택하지 않았다.
- **기종 추가 시**: 조형 공간이 기존 기종을 포함하거나 포함되는 관계면 `_BUILD_VOLUME` 값만
  넣으면 되고 매크로는 수정할 필요가 없다.
