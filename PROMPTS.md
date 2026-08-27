# 복붙용 작업 지시문

Claude Code에 그대로 붙여넣어 쓰는 프롬프트 모음.

---

## 세션 시작

```
docs/PROGRESS.md 와 docs/CURRENT_PHASE.md 읽고,
지금 이어서 할 작업이 뭔지 알려줘. 아직 코드는 쓰지 마.
```

---

## 1주차 — 기반

### 프로젝트 셋업
```
Godot 4 프로젝트를 초기화해줘.
- docs/ARCHITECTURE.md 의 디렉토리 구조를 따를 것
- project.godot 설정: 2D, 모바일 렌더러, 해상도 1080x1920 세로
- autoload 3개 등록: GameState, DataLoader, ObjectPool (빈 껍데기로)
- .gitignore 포함
```

### 데이터 로더
```
scripts/data/data_loader.gd 를 만들어줘.
- 게임 시작 시 data/*.json 전부 로드해서 Dictionary로 캐시
- get_hero(id), get_weapon(id), get_skill(id), get_segment(id) 접근자
- "_" 로 시작하는 키는 주석이므로 무시
- 파일이 없거나 파싱 실패하면 명확한 에러 로그 + 게임 중단
- 원본 Dictionary를 반환하지 말고 duplicate(true) 해서 줄 것
```

### 아이다 이동
```
아이다(플레이어) 이동을 구현해줘.
- 좌하단 가상 조이스틱 + 키보드 WASD 동시 지원
- 공격 없음. 이동만
- 카메라가 부드럽게 추적 (lerp)
- 이동속도는 하드코딩 말고 상수로 빼둘 것
```

### 오브젝트 풀
```
scripts/core/object_pool.gd 를 만들어줘.
- 씬별로 풀을 관리 (적, 투사체, 이펙트)
- acquire(scene_path) / release(node) 인터페이스
- 풀이 비면 자동 확장하되, 확장 시 경고 로그
- 반환 시 상태 초기화 (position, visible, 커스텀 reset() 호출)
docs/ARCHITECTURE.md 의 오브젝트 풀 섹션 참고.
```

---

## 2주차 — 전투 코어

### 적 스포너
```
적 스포너를 구현해줘.
- data/enemies.json 의 wave_pattern 을 따를 것
- 화면 밖 spawn_distance 위치에 랜덤 각도로 생성
- 시간에 따라 spawn_interval 이 start→end 로 선형 감소
- max_alive 초과 시 스폰 중단
- 반드시 ObjectPool 사용. instantiate() 직접 호출 금지
```

### 적 AI
```
data/enemies.json 의 적 3종을 구현해줘.
- rusher, tank: 플레이어 방향으로 직진. 경로탐색 쓰지 말 것
- shooter: keep_distance_and_shoot. 사거리 유지하며 투사체 발사
- 충돌은 단순 원형 판정
- 적 300마리 동시 표시에서 60fps 유지가 목표
```

### 무기 시스템
```
무기 시스템의 기반을 만들어줘.
- data/weapons.json 의 fire_mode 별로 분기하는 구조
- 지금은 impl_cost 가 "low" 인 것 중 whip, bolt, homing 3개만 구현
- 나머지는 나중에 추가할 수 있도록 확장 가능한 형태로
- 타겟팅: 가장 가까운 적
- 무기는 캐릭터에 종속되지 않음. 여러 캐릭터가 공유 가능해야 함
```

### DamagePacket
```
전투 데미지 파이프라인을 구현해줘.
docs/ARCHITECTURE.md 의 "전투 파이프라인" 섹션을 정확히 따를 것.
- DamagePacket 클래스: base, crit, element, source_hero_id
- 모든 데미지는 반드시 이 패킷을 거친다
- Enemy.take_damage(packet) 만 체력을 깎을 수 있다
- 직접 hp -= damage 하는 코드는 만들지 말 것
```

---

## 3주차 — 아이다 스킬

### 액티브 버튼 3개
```
아이다의 액티브 스킬 시스템을 구현해줘.
- 우하단 버튼 3개: buff / element / heal 슬롯
- data/skills.json 에서 장착된 스킬을 읽어옴
- 쿨타임 표시 (원형 게이지)
- 각 슬롯마다 자동시전 토글
- 마나 같은 추가 자원 없음. 쿨타임만
```

### 속성 부여 (가장 중요)
```
elem_fire 속성 부여를 구현해줘.
이게 프로토타입의 핵심 검증 항목이라 시각적 임팩트가 최우선이다.
- 지속시간 동안 파티 전체 공격에 화염 속성 부여
- 투사체 색상 변경 + 트레일 파티클
- 피격 시 화염 파티클 + 지속 피해(DoT)
- 적 체력바에 화상 표시
- "버튼을 눌렀는지 안 눌렀는지 화면만 봐도 즉시 알 수 있어야 한다"
```

---

## 4주차 — 진행 구조

### 층 진행
```
층 진행 시스템을 구현해줘.
- data/floors.json 의 seg_01 (1~6층)
- 층당 목표: 일정 시간 생존 또는 일정 수 처치
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
- 지금은 연출만. 가챠 재화 순환은 아직 구현하지 않음
```

---

## 검증 및 유지보수

### 데이터 검증
```
python3 scripts/validate_data.py 실행하고 오류 있으면 고쳐줘.
```

### 세션 종료
```
오늘 한 작업을 docs/PROGRESS.md 에 기록해줘.
그리고 범위를 넘어서 미뤄둔 아이디어가 있으면 docs/BACKLOG.md 에 추가해줘.
```

### 범위 이탈 방지
```
방금 제안한 기능이 docs/CURRENT_PHASE.md 범위 안에 있는지 확인해줘.
범위 밖이면 구현하지 말고 docs/BACKLOG.md 에만 적어줘.
```

### 캐릭터 추가 (Phase 3 이후)
```
data/heroes.json 에 새 가신을 추가하려고 해.
- 층: N
- 무기: (weapons.json 의 기존 무기 ID)
- 패시브: (heroes.json 의 _passive_types 참고)
JSON만 수정하고 코드는 건드리지 마. 코드 수정이 필요하다면 왜 필요한지 먼저 설명해줘.
```
