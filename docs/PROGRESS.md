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

### 알아둘 것
- `.tscn`에서 노드 참조 export(`@export var x: Node2D`)는 노드 헤더에
  `node_paths=PackedStringArray("x")`가 있어야 해석된다. `x = NodePath("...")`만 쓰면 null이 된다
- 헤드리스 검증: `~/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`
  `--headless --path C:/Users/kimcg/Desktop/LilaQuest/Sublike` (일반 exe는 stdout이 안 잡힌다)
- `--script` 모드에서는 autoload 가 **전역 식별자로 잡히지 않는다** (`Identifier not found: ObjectPool`).
  런타임에는 존재하므로 `root.get_node_or_null("ObjectPool")` 로 접근한다. 게임 실행에서는 정상
- **JSON 숫자는 전부 float으로 들어온다.** `Array.has()`는 타입까지 따지므로
  `6 in [1.0, 2.0, ...]` 는 false다 (`fl[5] == 6` 은 true인데도).
  JSON에서 읽은 정수를 비교할 땐 반드시 `int()`로 맞춘다. 층·티어·스택수 전부 해당

- [ ] 공식 튜토리얼 "Your first 2D game" 완주
- [ ] 2주차 남은 것: 웨이브 스포너 → 슬롯/가신 배치
      → 공격 타입 3종 → DamagePacket → 아이다 HP/실패 처리
