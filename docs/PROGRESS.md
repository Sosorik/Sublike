# 진행 기록

작업 완료 시마다 기록. Claude Code가 세션 간 컨텍스트를 이어받는 용도.

## 형식
```
## YYYY-MM-DD
- [완료] 항목 — 파일 경로
- [진행중] 항목 — 남은 것
- [막힘] 항목 — 이유
```

---

## 2026-08-28

- [완료] Godot 4.7.2 설치 확인 — `~/Downloads/Godot.app`
- [완료] 프로젝트 초기화 — `project.godot` (1280x720 / canvas_items+expand / sensor_landscape(=4) / mobile 렌더러)
- [완료] 디렉토리 구조 — `scenes/{lobby,battle,entities,ui}`, `scripts/{core,combat,ui,data}`, `assets/{sprites,audio}`
- [완료] GitHub 연결 및 최초 푸시 — https://github.com/Sosorik/Sublike
- [완료] GDD v2.0(라인 방어형) 반영 확인 — `validate_data.py` 무결성 통과 (가신 3/40, 고유스킬 3/15, 층 24/100)
- [완료] 좌표 규약 확정 — `docs/ARCHITECTURE.md` "좌표 규약" + `scripts/core/battle_layout.gd`
  전열 x=600(가장 오른쪽) → 중열 450 → 후열 300 → 아이다 80. 전열이 적을 먼저 만나 저지한다
  레인 y: front 380 / mid 300 / back 220. 스폰 x=1400, 아이다 피해선 x=120
- [완료] 진군 차단 규칙 확정 — `docs/ARCHITECTURE.md` "진군 차단 규칙"
  타워디펜스형. 같은 레인 가신과 접촉 시 적 정지 → 서로 공격 → 가신 사망 시 전진 재개
  가신은 레인과 무관하게 사거리(2D 거리) 안의 적을 공격한다
- [완료] 1주차 스크립트 작성 — `scripts/core/battle.gd`, `scripts/core/battle_layout.gd`, `scripts/combat/enemy.gd`
  적 좌측 직진 + 아이다 도달 시그널 + 레인 디버그 드로우. 스페이스바로 추가 스폰
- [완료] 씬 제작 — `scenes/entities/enemy.tscn` (Area2D + Sprite2D + CollisionShape2D), `scenes/battle/battle.tscn` (Node2D + Enemies)
- [완료] 역할 분담 변경 — `CLAUDE.md`: 씬(`.tscn`)도 Claude가 직접 만든다. 만들면 헤드리스 검증 필수
- [완료] `run/main_scene` 설정 — `res://scenes/battle/battle.tscn`
- [완료] **1주차 목표 달성** — 적 1마리가 오른쪽에서 왼쪽으로 이동 → 아이다 도달 확인
  `--headless` 실행 로그: `적이 아이다에 도달 — lane=front` (1400→120, 70px/s, 약 18초)

- [완료] JSON 데이터 로더 — `scripts/data/data_loader.gd` (autoload `DataLoader`, `project.godot`에 등록)
  7개 그룹 색인: heroes 3 / enemies 3 / attack_types 10 / hero_skills 3 / aida_skills 12 / run_upgrades 8 / segments 4
  모든 접근자는 `duplicate(true)` 깊은 복사본 반환 — 원본 캐시는 밖으로 나가지 않는다
  `_` 접두 항목(`_template`)은 색인에서 제외
- [완료] 오브젝트 풀 — `scripts/core/object_pool.gd` (autoload `ObjectPool`)
  PackedScene 단위 풀. `prewarm/acquire/release/stats/clear_idle`
  반납 시 트리에서 분리되므로 `_physics_process` 가 돌지 않는다
  노드는 `_on_acquired()` / `_on_released()` 콜백을 선택적으로 가질 수 있다
  검증: 재사용 3/3, 여유분 소진 시에만 신규 생성(created 4→6)
- [완료] 적 스폰을 풀 경유로 교체 — `battle.gd` (instantiate/queue_free 제거)
  적 속도를 `DataLoader.get_enemy("charger").speed` 에서 읽는다. 코드에 수치 없음
  재사용 시 시그널 중복 연결 방지 (`is_connected` 확인)
- [완료] 적 3종 데이터 스폰 — `enemy.gd` `setup(data)`, `battle.gd` JSON 순서 순환
  스탯(hp/speed/damage/defense/shard_value) 전부 `data/enemies.json` 에서. 코드에 수치 없음
  `lane_pref` 반영 — 중갑체는 전열 고정, 나머지는 레인 순환 (고정 적은 순환 카운터를 소비하지 않는다)
  임시 아트: `debug_color` / `debug_scale` 을 enemies.json 에 추가. 최종 스프라이트 나오면 제거
  검증: 돌격체 70/60, 사격체 40/40, 중갑체 30/260 — 풀 prewarm 16 안에서 신규 생성 0
- [완료] 웨이브 스포너 — `scripts/core/enemy_spawner.gd` (Battle 자식 노드)
  상태기계 SPAWNING → WAITING_CLEAR → INTERMISSION → 다음 웨이브 → DONE
  `wave_started` / `wave_cleared` / `floor_cleared` 시그널. `max_alive` 초과 시 스폰 보류
  웨이브 구성은 `enemies.json` 의 `wave_pattern.waves` (임시 수치. 밸런스는 5~6주차)
  종류가 뭉치지 않게 라운드로빈으로 편다. 난수 없음 — 실행마다 결과가 같다
  검증(time_scale 20배): 5웨이브 38마리 전부 클리어, 풀 신규 생성 0 (prewarm 24로 해결)
- [완료] `battle.gd` 축소 — 스폰 책임을 스포너로 넘기고 로그/레인 안내선만 담당
- [완료] 슬롯 3개 + 가신 3명 배치 — `scripts/combat/unit.gd`, `scripts/core/party.gd`, `scenes/entities/unit.tscn`
  리엔 front(600,380) atk12 range90 hp220 / 세라 mid(450,300) atk22 range320 hp110 / 니나 back(300,220) atk16 range520 hp80
  좌표는 `BattleLayout.slot_position()` — ARCHITECTURE 좌표표와 일치 확인
  가신은 풀을 쓰지 않는다 (몇 명뿐이고 끝까지 살아 있다). 라인당 1칸, 중복 배치는 오류
  heroes.json 에 임시 아트 `debug_color`/`debug_scale` 추가
  아직 공격하지 않는다 — 적이 그냥 지나간다. 다음 항목에서 붙는다
- [완료] 공격 타입 3종 + DamagePacket 파이프라인
  `scripts/combat/damage_packet.gd` — 모든 피해가 거치는 단일 통로. `hp -= x` 를 밖에 두지 않는다
  `scripts/combat/projectile.gd` + `scenes/entities/projectile.tscn` — 직선 투사체, 관통 시 중복 명중 방지
  `unit.gd`: nearest_single(근접) / projectile_single / projectile_pierce
  타겟 = 사거리 안에서 **가장 왼쪽 적**. 레인 무관, 2D 거리
  치명타는 발사 시 1회만 굴린다. 관통이라도 맞는 적마다 다시 굴리지 않는다
  방어력은 맞는 쪽이 뺀다 (`Enemy.take_damage`). 최소 피해는 `combat_rules.json`
  `data/combat_rules.json` 신규 — crit_mult 2.0 / min_damage 1.0. `DataLoader.get_rule()`
  충돌 레이어: 가신 1 / 적 2 / 투사체 4(마스크 2)
  검증(층 1회): 처치 26 / 아이다 통과 12. 평균피해 리엔 12.46·세라 24.26·니나 16.8 — 데이터와 일치
  풀 무결성 idle=created (투사체 48, 적 24), 에러 0
- [대기] 밸런스 — 38마리 중 12마리가 아이다까지 간다. 진군 차단이 없어서다. 수치 조정은 5~6주차
- [완료] 아이다 HP / 실패 처리 — `scripts/combat/aida.gd`, battle.tscn 에 Aida 노드
  적이 피해선(x<120)을 넘으면 `enemy.damage` 만큼 아이다 체력이 깎인다
  적→아이다 피해도 DamagePacket 을 거친다. `source_hero_id` 는 비움 = 가신이 준 피해가 아님
  체력 0 → `died` → 스포너 정지 + 실패 로그. 리트라이는 4주차 항목
  스포너는 아이다를 모른다 — `enemy_reached_aida` 시그널을 Battle 이 받아 중계한다
  디버그 체력바를 아이다 위에 그린다 (정식 HUD 는 3주차)
  `combat_rules.json` 에 `aida_max_hp` 100 추가 (임시 수치)
  검증: 웨이브 4까지 8마리 돌파 → HP 8 → 웨이브 5에서 실패. 처치 25
- [완료] 진군 차단 규칙 — `unit.gd` 저지/피격, `enemy.gd` 저지 상태기계
  적이 같은 레인 가신에게 닿으면 정지하고 `attack_interval` 마다 때린다
  `block_count` 만큼만 저지한다. 넘친 적은 안 막히고 지나간다 (명일방주 저지 수)
  가신 사망 → 붙잡던 적 전원 전진 재개. 적 사망/반납 시 저지 목록에서 스스로 빠진다
  적→가신 피해도 DamagePacket 경유. 가신 방어력은 맞는 쪽에서 뺀다
  레인 그룹(`unit_front` 등)으로 찾는다 — 적이 Party 를 참조하지 않는다
  임시 수치: 저지 수 리엔3 / 세라1 / 니나0, 적 공격간격 1.0 / 1.5 / 2.0, 접촉거리 40
  **효과: 처치 26→32, 돌파 12→6, 실패→층 클리어(아이다 6 남음)**
  웨이브 1~3 무실점 → 웨이브 4에서 리엔 전사 → 전열이 뚫리자 나머지가 통과

## 2주차 완료

전투 루프가 처음으로 끝까지 돈다. 스폰 → 교전 → 처치/돌파 → 층 클리어 또는 실패.
## 3주차 — 아이다 + 컷인

- [완료] 아이다 스킬 시스템 — `scripts/combat/aida_skills.gd` (슬롯 buff/element/heal)
  장착: 격려(atk_mult 1.5, 5s, 쿨12) / 화염 부여(6s, 쿨14) / 치유(40, 쿨10)
  슬롯에 맞지 않는 스킬을 넣으면 오류로 잡는다
- [완료] 버프·속성 컨테이너 — `unit.gd` `apply_buff` / `apply_element` + `get_atk/get_atk_speed/get_crit/get_range`
  공격 로직은 반드시 getter 를 쓴다. 기본 스탯은 건드리지 않는다
- [완료] 힐 — `aida.gd` `heal()`
- [완료] 액티브 버튼 3개 + 쿨타임 게이지 + 자동 시전 토글
  `scripts/ui/battle_hud.gd`, `scenes/ui/battle_hud.tscn`. 키보드 1/2/3, A 로 자동시전
  버튼 위젯은 코드로 만든다 — 슬롯 3벌을 씬에 복사해 두면 한 곳만 고쳐도 어긋난다
  검증: 쿨타임 12/14/10초 정확, atk 12→18 후 5초 뒤 복귀, element 6초 뒤 해제
- [완료] 속성 부여 (화염) — `enemy.gd` 지속피해 + 시각
  `DamagePacket` 에 `element_params` / `ignore_defense` 추가
  수치는 `aida_skills.json` 의 effect 가 그대로 실려 온다 — 두 곳에 적지 않는다
  지속피해는 방어력을 무시한다. 틱당 피해가 작아 방어력을 빼면 최소피해로 떨어져 오히려 더 아프다
  `dot_tick` 0.25초마다 적용. 매 프레임이면 피해 묶음만 낭비된다
  중첩 3까지. 꽉 차면 가장 먼저 꺼질 스택의 시간을 새로 고친다
  시각: 불붙은 적은 속성색으로 물들고 깜빡인다. 속성이 실린 투사체도 속성색
  검증: 자동시전 45초에 불붙은 적 다수 관측, 최대 2중첩
- [완료] 스킬 컷인 — `scripts/ui/cutin_layer.gd`, `scenes/ui/cutin_layer.tscn`
  슬라이드 인 0.15 + 유지 0.3 + 슬라이드 아웃 0.15 = 0.6초. 화면 플래시 동반
  Tween 만 사용. 전투는 멈추지 않는다
  연속 발동은 큐잉해서 겹치지 않게. 큐가 2를 넘으면 오래된 것을 버린다
  검증: 3연속 발동이 0.61 / 1.21 / 1.81s 에 순차 종료. 패널 x −460↔24 왕복

## 3주차 완료

버튼 3개로 개입하고, 화염이 화면에서 눈에 띄고, 컷인이 뜬다.
Phase 1 검증 질문 3번(속성이 눈에 띄는가) / 4번(컷인이 매력적인가) 을 이제 판단할 수 있다.
## 아트 도입 (3주차 검증용)

- [완료] 캐릭터 아트 도입 — cogabushi "Free 25 Fantasy Character Asset Pack" (itch.io)
  캐스팅: 아이다=117(보라 마녀) / 리엔=124(창+방패 기사) / 세라=114(권총) / 니나=121(라이플)
  `25_upper`=상반신 6표정, `25_full/f_1`=대기, `f_3`=무기 든 전투자세, `25_pose`=대형 액션 컷인
  컷인은 **슬롯마다 다른 표정** (buff=2 / element=4 / heal=6). 데이터는 `data/aida.json`
  가신 스프라이트는 대기↔전투 두 장 교체 (프레임 애니메이션 아님). 발끝이 레인 y 에 닿게 offset
  `aida_max_hp` 를 combat_rules → aida.json 으로 이동 (전투 규칙이 아니라 캐릭터 데이터다)
- [주의] **에셋은 저장소에 없다.** 재배포 금지 조항 + 이 저장소는 공개다
  `.gitignore` 로 원본 팩·zip·가공본 전부 제외. 받는 법은 `assets/sprites/LICENSED_ASSETS.md`
- [주의] 이 팩은 **AI 생성 후 사람이 가필**한 이미지다. 출시 시 플랫폼 고지 의무 확인할 것
- [완료] 적 3종 아트 — 돌격체=118(쌍도끼) / 사격체=123(머스킷) / 중갑체=112(플레일+대형방패)
  좌우 반전해서 아군과 반대 방향을 본다. `sprite_height` 로 크기 차등 (112/108/142)
  저지당해 가신을 때릴 때 전투 자세로 교체
  스프라이트를 쓰면 기본색이 흰색이라 화염 지속피해의 주황 물듦이 그대로 살아난다
## 4주차 — 진행 구조

- [완료] 층 진행 (6층) — `scripts/core/run_state.gd` (RunState 노드)
  구간 계수 × 층당 계수^순번. `floors.json` 의 `per_floor_curve` (임시 ×1.12 / ×1.05)
  1층 ×1.00 → 6층 ×1.76. 적 체력은 스포너가 복사본에 곱한다 (JSON 원본 불변)
  스폰 간격은 배수로 나눈다. 6층은 보스층으로 인식 (보스 구현은 다음 항목)
- [완료] 층/웨이브 HUD 표시 — 상단 중앙 "N층 (n/6)   웨이브 k/5"
- [완료] 실패 / 리트라이 — 아이다 사망 또는 구간 클리어 시 결과판
  리트라이는 `reload_current_scene()` — 쓰러진 가신·남은 적·풀·버프가 전부 초기화된다
  R 키 또는 버튼
- [완료] 층 클리어 시 강화 3택 + 런 내 강화 8종
  후보는 최대 스택에 안 찬 것 중에서 무작위 3개. 고르는 동안 `get_tree().paused`
  HUD 는 `process_mode = ALWAYS` 라 정지 중에도 버튼이 눌린다
  누적 방식: 스택 n이면 값이 n제곱(배수) 또는 n배(덧셈). **매번 통째로 다시 반영**한다
  — 증분으로 곱하면 재적용 시 두 번 곱해진다
  체력 상한이 오르면 오른 만큼 회복시킨다 (안 그러면 고른 보람이 없다)
  검증: atk 12→15.87(×1.15²), 리엔 hp 220→286(전열만), 니나 사거리 520→650(후열만),
  아이다 100→130, 격려 쿨 12→10.2 — 전부 기댓값 일치
- [완료] 보스 (6층) + 소환 연출
  `boss_warden`(탑의 파수관, 107 아트) — hp900 / 방어18 / 피해40 / 느림. 전열 고정
  일반 웨이브 5개를 클리어한 뒤 보스 하나가 나온다. 층 난이도 배수도 그대로 받는다
  (6층 기준 hp 1586). 격파 → **소환 연출**: 해금 가신의 일러가 2초간 슬라이드 인
  연출은 큐를 무시하고 즉시 재생한다 — 놓치면 안 되는 장면이다
  구간별 보스 적은 `floors.json` 의 `boss_enemy_id`, 해금 가신은 `boss_hero_id`

## 4주차 완료

한 판이 처음부터 끝까지 돈다. 1층 → 강화 3택 → … → 6층 보스 → 소환 → 구간 클리어.
실패하면 결과판에서 리트라이.
## 전투 연출 (아트 리소스 없이 임팩트 올리기)

- [완료] 피해 숫자 + 피격/처치 파티클 — `scripts/core/effects.gd` (autoload `Effects`)
  `scenes/effects/damage_number.tscn`, `hit_effect.tscn` — 둘 다 풀 필수 대상
  ARCHITECTURE 의 오브젝트 풀 목록에 있던 DamageNumber / HitEffect 를 이제 채웠다
  치명타는 숫자가 커지고 금색. 아군 피격은 붉은색. 속성이 실린 타격은 속성색으로 터진다
  처치는 더 크게 터진다 (파티클 22개, 속도 1.9배)
  **지속피해는 숫자를 띄우지 않는다** (`silent_number`) — 0.25초마다 뜨면 화면이 가려진다
  Effects 는 전투 씬이 `set_root()` 로 컨테이너를 넘겨 줘야 동작한다. 안 넘기면 조용히 무시
  검증: 30초 전투에서 동시 최대 7개, 풀 신규 생성 0 (prewarm 32/24 안에서 해결), 누수 없음
- [완료] 가신/적 체력바 — `scripts/ui/health_bar.gd`, unit.tscn·enemy.tscn 에 자식 노드
  **부모가 아니라 자식으로 둔다** — 부모의 `_draw()` 는 자식 스프라이트보다 먼저 그려져 가려진다
  텍스처 없이 사각형 두 개로 그린다. 값이 바뀔 때만 `queue_redraw()`
  가신은 항상 표시(3명뿐), **적은 피해를 입은 뒤부터** 표시 (수가 많아 항상 띄우면 지저분하다)
  남은 비율에 따라 색이 변한다 — 아군 초록→노랑→빨강, 적 빨강→주황→노랑
  폭은 스프라이트 폭의 90%%. 보스는 자동으로 넓은 바가 된다
  검증: 적 25피해 → 1.00→0.58(hp 35/60), 리엔 60피해 → 0.95→0.71(hp 156/220)
- [수정] **아이다 캐스팅 오류 정정** — 117(여성) → **113(소년)**
  GDD 3.3: *"17세. 왜소한 체구. **남자 힐러.** 조롱거리였다. 힐러는 여자의 일이라 여겨졌고…"*
  GDD 3.4 의 "40인이 전원 소녀 형태" 는 **가신만** 해당한다. 아이다는 남자다
  → 아트를 고르기 전에 GDD 3장(캐릭터/스토리)을 먼저 읽는다. 화려함으로 고르면 설정을 어긴다
- [완료] 아이다 전신 표시 — `aida.json` 의 `sprite`, 전장 좌측 (80,300) 에 선다
  키 100px — 가신 118 보다 작다 (왜소한 체구)
  디버그 초록 원과 임시 체력바는 제거. 체력은 HUD 좌상단에 있다
## 설계 전환 — 명일방주식 DP 배치 (GDD v3.0)

- [완료] GDD 4.1/4.2/4.3/4.4/4.6 개정 + ARCHITECTURE 좌표·씬 구조 + CURRENT_PHASE 범위
  **문제**: 1~4주차를 다 만들고 나니 전투 중 플레이어가 할 게 버튼 3개뿐이었다
  가신 3명을 슬롯 3칸에 넣는 구조라 **편성 조합이 정확히 1가지** —
  검증 질문 1번("편성을 바꾸면 재밌게 달라지는가")을 구조적으로 검증할 수 없었다
  레퍼런스인 명일방주에서 가져온 건 저지 수 하나뿐이고, 핵심인 **전투 중 배치**가 빠져 있었다
  **해결**: 레인3 × 열3 = 9타일, 손패 8명, 동시 배치 6명, DP 자원
  명일방주 원본 그대로: DP 초당 1 / 재배치 ×1.5→×2(상한 99) / 철수 환급 절반(내림)
  / 지상=근접·고지=원거리 / 저지 0 유닛은 근접 적이 지나침
  **일부러 뺀 것**: SP 충전 방식 — 자원 축이 DP·SP 둘이면 "한 손 조작"(GDD 1.1)이 깨진다
  출처: arknights.wiki.gg (Deployment Point / Cost / Operator)

> **교훈: 범위와 검증 질문이 모순되면 다 만들고 나서야 드러난다.**
> 기획 문서를 받으면 "이 범위로 저 질문을 검증할 수 있는가" 를 먼저 따진다.
## 5주차 — DP 배치 시스템

- [완료] 1~3단계: 좌표 · 데이터 · DP 로직
  `battle_layout.gd` 재작성 — 레인3(a/b/c, y 236/348/460) × 열3(x 680/520/360) = 9타일
  열1·2 지상(근접), 열3 고지(원거리). `tile_position()` / `can_place()` / `column_kind()`
  `heroes.json` 재작성 — 가신 8명 (지상 5 / 고지 3), `line` → `deploy_type` + `deploy_cost`
  `combat_rules.json` 에 DP 규칙 8개. `run_upgrades.json` 의 front/back → ground/high
  `party.gd` 전면 재작성 — DP, 배치, 철수, 재배치 코스트, 동시 배치 상한
  `enemy.gd` — 같은 레인에서 **가장 오른쪽 가신부터** 저지당한다 (열1 먼저, 뚫리면 열2)
  힐 대상에 지상 가신 추가 (GDD 4.4)
  검증(명일방주 원본과 대조): 원가 14 → 재배치 21(×1.5) → 28(×2),
  환급 14→7 / 21→10(절반 내림), 동시 배치 상한 6, 타일 종류 제한, 중복 배치 차단
- [완료] 4~6단계: 배치 UI
  `scripts/ui/deploy_field.gd` — 격자 그리기 + 타일 클릭. 격자는 Battle 에서 여기로 옮겼다
  손패에서 고르면 **놓을 수 있는 칸만 밝아지고 나머지는 덮인다**. 우클릭/빈곳 클릭으로 해제
  HUD: DP 표시("DP 26/99  배치 1/6"), 손패 8칸(이름·종류·코스트), 철수 버튼(환급량 미리보기)
  못 내는 이유는 `deploy_blocker()` 가 문자열로 주고 UI 가 툴팁·로그로 그대로 보여준다
  검증: 시작 DP 10 에서 유나(10)·리나(9)만 활성 — 의도대로 첫 판단이 생긴다
  배치 14 → DP 26, 철수 → +7, 타일 해제까지 확인
- [완료] 선봉(Vanguard) 도입 — 명일방주 **Charger** 분파를 그대로
  Pioneer / Flagbearer / Tactician 은 SP 스킬이 필요해 못 쓴다. Charger 만 순수 특성이다
  카린(art 116) — 코스트 7, 저지 1, **처치 시 +1 DP**, **철수 시 원가 전액 환급**
  손패에서 mira 를 빼고 넣었다 (지상 5 / 고지 3 유지)
  `traits` 블록 신설 — 코드 분기 대신 데이터로 역할을 만든다
  처치 귀속 경로 신설: `packet.source_hero_id → Enemy._killer_id → enemy_killed → Party`
  검증: 3킬 → +3 DP, 선봉 아닌 가신은 0, 재배치로 코스트 7→10 이어도 환급은 원가 7 고정
  **효과: 철수에 처음으로 이유가 생겼다.** 싸게 깔아 벌고 → 빼서 딜러로 교체

### 알아둘 것
- `.tscn`에서 노드 참조 export(`@export var x: Node2D`)는 노드 헤더에
  `node_paths=PackedStringArray("x")`가 있어야 해석된다. `x = NodePath("...")`만 쓰면 null이 된다
- 헤드리스 검증: `~/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  `--headless --path C:/Users/kimcg/Desktop/LilaQuest/Sublike` (일반 exe는 stdout이 안 잡힌다)
- **새 `class_name` 은 `--import` 를 돌려야 전역 등록된다.** 등록 전에 그 클래스를 쓰는
  스크립트는 파싱에 실패하고, 그 상태로 씬을 저장하면 **export 값이 전부 null 로 날아간다.**
  새 class_name 을 추가했으면 씬을 건드리기 전에 `--import` 부터 돌린다
- 형제 노드의 `_ready()` 는 씬 트리에 놓인 순서대로 돈다. 순서가 중요하면 노드 순서로 정한다
- **`PackedScene.pack()` 은 인스턴스 경계를 무너뜨린다.** 다른 씬을 instance 로 품은 씬에
  정규화(pack+save)를 돌리면 `instance=` 가 풀려 내부 노드 속성이 부모 씬에 박제된다.
  그러면 원본 씬을 고쳐도 반영되지 않는다. **인스턴스를 품은 씬은 손으로 쓰고 정규화하지 않는다**
- **자식 노드의 `_ready()` 가 부모보다 먼저 돈다.** 자식이 `_ready()` 에서 바로 시그널을
  emit 하면 부모가 연결하기 전이라 놓친다. `start.call_deferred()` 로 트리 전체가 준비된 뒤 시작한다
- 긴 진행을 검증할 땐 `Engine.time_scale` 을 올린다. 층 하나(실시간 3분+)를 10초에 확인
- `--script` 모드에서는 autoload 가 **전역 식별자로 잡히지 않는다** (`Identifier not found: ObjectPool`).
  게임 스크립트가 autoload 를 참조하면 그 모드에선 아예 컴파일이 안 된다.
  **검증용 씬을 만들어 `godot --headless res://_probe.tscn` 으로 돌린다** — 정상 메인루프라 autoload 가 산다
- **물리 콜백(`area_entered`, `_physics_process`) 안에서 노드를 트리에서 떼면 안 된다.**
  Godot 이 거부하고, 부모가 남은 채 풀에 들어가 재사용 시 `already has a parent` 로 이어진다.
  시그널을 `emit.call_deferred()` 로 미뤄서 물리 프레임 밖에서 반납한다
- **풀 오브젝트의 시그널에 사용자가 핸들러를 붙이면 재사용마다 하나씩 쌓인다.**
  투사체 반납을 쏜 가신이 맡았더니 한 번 만료에 여러 번 반납돼 풀이 조용히 망가졌다
  (`idle > created` 가 신호였다). 반납은 오브젝트 자신이 한다
- **JSON 숫자는 전부 float으로 들어온다.** `Array.has()`는 타입까지 따지므로
  `6 in [1.0, 2.0, ...]` 는 false다 (`fl[5] == 6` 은 true인데도).
  JSON에서 읽은 정수를 비교할 땐 반드시 `int()`로 맞춘다. 층·티어·스택수 전부 해당

- [ ] 공식 튜토리얼 "Your first 2D game" 완주
- [ ] 5~6주차: 편성 조합 테스트 → 밸런스 → **직접 20판 플레이** → 외부인 3명 테스트
- [ ] 밸런스 메모: 차단+스킬이 붙은 뒤 초반 웨이브가 무실점이다. 웨이브를 올리거나 쿨을 늘려야 한다
- [ ] 광역 강제 정지(`taunt_wall` / `guard_wall`) — 상시 저지와 별개. 3주차 스킬
