# 복붙용 작업 지시문

Claude Code에 그대로 붙여넣어 쓴다.

---

## 세션 시작 / 종료

### 시작
```
docs/PROGRESS.md 와 docs/CURRENT_PHASE.md 읽고
지금 이어서 할 작업이 뭔지 알려줘. 아직 코드는 쓰지 마.
```

### 종료
```
오늘 한 작업을 docs/PROGRESS.md 에 기록해줘.
범위를 넘어서 미뤄둔 아이디어가 있으면 docs/BACKLOG.md 에 추가해줘.
```

---

## 첫 세션

### 1) 파악
```
CLAUDE.md, GDD.md, docs/CURRENT_PHASE.md 읽고
프로젝트가 뭔지, 지금 뭘 만들어야 하는지 요약해줘. 아직 코드는 쓰지 마.
```

### 2) 프로젝트 초기화
```
Godot 4 프로젝트를 초기화해줘.
- 2D, Mobile 렌더러
- 기준 해상도 1280x720 가로
- stretch mode: canvas_items, aspect: expand
- 화면 방향 가로 고정
- docs/ARCHITECTURE.md 의 디렉토리 구조대로 폴더 생성
- .gitignore 포함
- project.godot 설정까지

.tscn 은 만들지 마. 내가 에디터에서 만들 거야.
```

---

## 1주차 — 화면에 뭔가 나오게 하기

목표: **적 1마리가 오른쪽에서 걸어오고, 가신 1명이 쏴서 죽인다.**

### 씬 만들기 (안내 요청)
```
Battle 씬과 Enemy 씬, Unit 씬을 만들려고 해.
Godot 에디터에서 어떤 노드를 어떤 순서로 추가해야 하는지
클릭 단위로 알려줘. 나는 Godot 초보야.
docs/ARCHITECTURE.md 의 씬 구조와 좌표 규약을 따를 것.
```

### 적 이동
```
scripts/combat/enemy.gd 를 만들어줘.
- x가 감소하는 방향으로 직진. 경로탐색 쓰지 마
- data/enemies.json 의 charger 수치 사용
- x < 120 에 도달하면 도착 시그널 발생
- 지금은 색깔 사각형이어도 됨
```

### 가신 자동 공격
```
scripts/combat/unit.gd 를 만들어줘.
- 슬롯 좌표에 고정. 이동/방향전환 없음
- 사거리 내에서 가장 왼쪽(=가장 위협적인) 적을 타겟
- atk_speed 간격으로 공격
- data/heroes.json 의 sera(single_shot) 수치 사용
```

### 데미지 처리
```
DamagePacket 파이프라인을 구현해줘.
docs/ARCHITECTURE.md 의 "전투 파이프라인" 섹션을 정확히 따를 것.
- DamagePacket 클래스: base, is_crit, element, source_hero_id
- Enemy.take_damage(packet) 만 체력을 깎을 수 있다
- 직접 hp -= damage 하는 코드는 만들지 마
```

---

## 2주차 — 전투 코어

### 데이터 로더
```
scripts/data/data_loader.gd 를 만들어줘.
- 시작 시 data/*.json 전부 로드해서 Dictionary 캐시
- get_hero(id), get_attack_type(id), get_hero_skill(id),
  get_aida_skill(id), get_segment(id), get_enemy(id) 접근자
- "_" 로 시작하는 키는 주석이므로 무시
- 파싱 실패 시 명확한 에러 로그 + 중단
- 원본을 반환하지 말고 duplicate(true) 해서 줄 것
```

### 오브젝트 풀
```
scripts/core/object_pool.gd 를 만들어줘.
- 씬별 풀 관리 (적, 투사체, 이펙트, 데미지숫자)
- acquire(scene_path) / release(node)
- 풀이 비면 자동 확장하되 경고 로그
- 반환 시 상태 초기화
```

### 웨이브 스포너
```
웨이브 스포너를 구현해줘.
- data/enemies.json 의 wave_pattern 을 따를 것
- spawn_x 에서 lanes_y 중 하나에 스폰
- 층당 웨이브 5, 웨이브 사이 정비 3초
- 반드시 ObjectPool 사용. instantiate() 직접 호출 금지
```

### 라인 슬롯
```
전열/중열/후열 슬롯 시스템을 구현해줘.
- 각 라인에 슬롯 N개 (프로토타입은 각 1개)
- data/heroes.json 의 line 값으로 배치 가능 여부 판정
- 좌표는 docs/ARCHITECTURE.md 의 좌표 규약 사용
```

---

## 3주차 — 아이다 + 컷인 (가장 중요)

### 버튼 3개
```
아이다의 액티브 스킬 시스템을 구현해줘.
- 하단 버튼 3개: buff / element / heal
- data/aida_skills.json 에서 장착 스킬을 읽어옴
- 원형 쿨타임 게이지
- 슬롯별 자동시전 토글
- 마나 같은 추가 자원 없음. 쿨타임만
- 아이다는 이동하지 않음
```

### 속성 부여 (핵심 검증 항목)
```
elem_fire 속성 부여를 구현해줘.
이게 프로토타입의 핵심 검증 항목이라 시각적 임팩트가 최우선이다.
- 지속시간 동안 전 가신 공격에 화염 속성 부여
- 투사체 색상 변경 + 트레일 파티클
- 피격 시 화염 파티클 + 지속 피해(DoT)
- 적에게 화상 표시
- "버튼을 눌렀는지 안 눌렀는지 화면만 봐도 즉시 알 수 있어야 한다"
```

### 컷인 연출 (핵심 검증 항목)
```
스킬 컷인을 구현해줘.
docs/ARCHITECTURE.md 의 "컷인 시스템" 섹션대로.
- 상반신 이미지 슬라이드 인 0.15s → 유지 0.3s → 아웃 0.15s
- 대사 텍스트 (data 의 cutin_line) + 화면 플래시
- 전투는 멈추지 않는다
- 정지 이미지 + Tween 만 사용. 애니메이션 프레임 없음
- 연속 발동 시 큐잉
- 지금은 이미지 대신 색깔 사각형이어도 됨
```

---

## 4주차 — 진행 구조

### 층 진행
```
층 진행 시스템을 구현해줘.
- data/floors.json 의 seg_01 (1~6층)
- 층당 웨이브 5 클리어 시 다음 층
- 층 클리어 시 강화 3택 UI (data/run_upgrades.json 에서 랜덤 3개)
- difficulty_curve 적용
- 6층은 보스층
```

### 소환 연출
```
보스 격파 후 소환 연출을 만들어줘.
- 보스 사망 → 화면 정지 → 마석 발광 → 가신 강림
- 2~3초, 스킵 가능
- 연출 후 해금된 캐릭터 카드 표시
- 가챠 재화 순환은 아직 구현하지 않음
```

---

## 유지보수

### 데이터 검증
```
python3 scripts/validate_data.py 실행하고 오류 있으면 고쳐줘.
```

### 범위 이탈 방지
```
방금 제안한 기능이 docs/CURRENT_PHASE.md 범위 안에 있는지 확인해줘.
범위 밖이면 구현하지 말고 docs/BACKLOG.md 에만 적어줘.
```

### 가신 추가 (Phase 3 이후)
```
data/heroes.json 에 새 가신을 추가하려고 해.
- 층: N
- 라인: front/mid/back
- 공격타입: (attack_types.json 의 기존 ID)
- 고유스킬: (hero_skills.json 의 기존 ID)
JSON만 수정하고 코드는 건드리지 마.
코드 수정이 필요하면 왜 필요한지 먼저 설명해줘.
```

### 씬 구조가 필요할 때
```
(기능) 을 만들려면 어떤 씬 구조가 필요한지
Godot 에디터 클릭 단위로 알려줘. .tscn 은 직접 만들지 마.
```
