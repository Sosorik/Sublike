# 세이브 데이터 포맷

⚠️ **이 스키마를 변경할 때는 반드시 마이그레이션 코드를 함께 작성한다.**
여기서 버그가 나면 유저 데이터가 날아가고 복구가 안 된다.

## 위치
`user://save.json` (Godot user 디렉토리)

## 스키마

```json
{
  "version": 1,
  "created_at": "ISO8601",
  "updated_at": "ISO8601",

  "progress": {
    "cleared_segments": ["seg_01", "seg_02"],
    "highest_floor": 12,
    "depth_cleared": { "seg_01": 3, "seg_02": 1 }
  },

  "heroes": {
    "lien": { "unlocked": true, "level": 5, "awaken": 1 },
    "sera": { "unlocked": true, "level": 3, "awaken": 0 }
  },

  "aida": {
    "permanent": {
      "heal_power": 2,
      "move_speed": 1,
      "party_slots": 2,
      "max_hp": 3
    },
    "equipped_skills": {
      "buff": "buff_power",
      "element": "elem_fire",
      "heal": "heal_instant"
    },
    "unlocked_skills": ["buff_power", "elem_fire", "heal_instant"],
    "auto_cast": { "buff": false, "element": false, "heal": true }
  },

  "party": ["lien", "sera"],

  "currency": {
    "shards": 1240
  },

  "gacha": {
    "pity_counter": 37,
    "total_pulls": 63
  },

  "story": {
    "seen_beats": ["interlude_10"],
    "ending": null
  },

  "settings": {
    "bgm": 0.7, "sfx": 0.8, "language": "ko"
  }
}
```

## 규칙

1. **version 필드 필수.** 로드 시 버전 비교 → 낮으면 마이그레이션
2. **없는 키는 기본값으로 채운다.** 크래시 금지
3. **저장은 원자적으로**: 임시 파일에 쓰고 → 검증 → rename
4. 로드 실패 시 백업(`save.bak.json`) 시도 → 그것도 실패하면 새 게임 안내
5. 저장할 때마다 이전 파일을 `.bak`으로 복사

## 마이그레이션 패턴

```gdscript
func migrate(data: Dictionary) -> Dictionary:
    var v: int = data.get("version", 0)
    if v < 1:
        data = _migrate_0_to_1(data)
    # if v < 2: ...
    data["version"] = CURRENT_VERSION
    return data
```
