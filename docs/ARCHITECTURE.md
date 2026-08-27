# 아키텍처

## 씬 구조

```
Main (Node)
├── GameState (autoload)      # 전역 상태. 진행도, 해금 목록
├── DataLoader (autoload)     # JSON 로드 및 캐시
├── ObjectPool (autoload)     # 적/투사체/이펙트 풀
│
├── Lobby (탑 기슭)
│   ├── SegmentSelect         # 구간 선택
│   ├── PartyEdit             # 파티 편성
│   ├── SkillEquip            # 아이다 슬롯 3개 장착
│   └── SummonUI              # 가챠
│
└── Run (등반)
    ├── Arena                 # 랜덤 생성 맵
    ├── Aida                  # 플레이어. 이동 + 액티브 3
    ├── Party (Node2D)        # 소녀 1~3명. 아이다 추종
    ├── EnemySpawner
    ├── ProjectileLayer
    └── RunHUD                # 체력, 층, 쿨타임 3버튼
```

## 데이터 흐름

```
data/*.json
   ↓ DataLoader (게임 시작 시 1회)
   ↓
Dictionary 캐시
   ↓ 조회
HeroInstance / WeaponInstance  ← 런타임 객체
   ↓
전투 시스템
```

**중요**: JSON 원본을 직접 수정하지 않는다. 런타임 수치는 인스턴스에 복사해서 쓴다.

## 전투 파이프라인

```
1. Weapon.tick(delta)
2. 쿨타임 도달 → 타겟 탐색 (가장 가까운 적)
3. 투사체/공격 생성 (풀에서 꺼냄)
4. 충돌 → DamagePacket 생성
   { base, crit, element, source_hero_id }
5. 버프 적용 (아이다 슬롯1)
6. 속성 적용 (아이다 슬롯2)
7. 패시브 적용 (캐릭터별)
8. Enemy.take_damage(packet)
9. 사망 → 파편 드롭 + 풀 반환
```

**DamagePacket을 반드시 거친다.** 여기가 모든 버프/속성/패시브가 합류하는 지점이다.
직접 `hp -= damage` 하는 코드를 만들지 않는다.

## 오브젝트 풀

```gdscript
# 필수 대상
- Enemy (300+)
- Projectile (500+)
- DamageNumber
- HitEffect
- ShardPickup

# 금지
instantiate() / queue_free() 를 매 프레임 호출하는 코드
```

## 상태 저장 시점

- 로비 진입 시
- 런 종료 시 (클리어/사망 모두)
- 파편 소비 시
- 앱 백그라운드 전환 시 (모바일)

**런 도중에는 저장하지 않는다.** 중간 저장은 스코프 밖.
