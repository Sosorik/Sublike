class_name Unit
extends Area2D

## 가신. 고정 슬롯에서 이동하지 않는다. 방향 전환도 없다.
## 스탯은 전부 data/heroes.json 에서 온다. 코드에 수치를 적지 않는다.
##
## 공격은 다음 항목(공격 타입 3종)에서 붙인다. 지금은 배치와 스탯 보유까지.

## setup() 전에 참조될 때만 쓰는 대비값.
const FALLBACK_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

var hero_id: String = ""
var display_name: String = ""
var line: String = "front"
var attack_type_id: String = ""
var skill_id: String = ""

var max_hp: float = 0.0
var hp: float = 0.0
var atk: float = 0.0
var atk_speed: float = 1.0
var atk_range: float = 0.0    ## range 는 GDScript 내장 함수 이름이라 못 쓴다
var crit: float = 0.0
var defense: float = 0.0


## data/heroes.json 의 항목 하나를 받아 스탯과 외형을 세팅한다.
## 레벨 성장(growth)은 Phase 1 범위 밖이라 base_stats 를 그대로 쓴다.
func setup(data: Dictionary) -> void:
	if data.is_empty():
		push_error("Unit.setup: 빈 데이터가 들어왔다.")
		return

	hero_id = str(data.get("id", ""))
	display_name = str(data.get("name", hero_id))
	line = str(data.get("line", "front"))
	attack_type_id = str(data.get("attack_type_id", ""))
	skill_id = str(data.get("skill_id", ""))

	var stats: Dictionary = data.get("base_stats", {})
	max_hp = float(stats.get("hp", 1.0))
	hp = max_hp
	atk = float(stats.get("atk", 0.0))
	atk_speed = float(stats.get("atk_speed", 1.0))
	atk_range = float(stats.get("range", 0.0))
	crit = float(stats.get("crit", 0.0))
	defense = float(stats.get("defense", 0.0))

	# 임시 아트. 최종 스프라이트가 나오면 이 두 줄을 지운다.
	modulate = Color.from_string(str(data.get("debug_color", "")), FALLBACK_COLOR)
	scale = Vector2.ONE * float(data.get("debug_scale", 1.0))


## 라인 슬롯에 세운다. 이후 이 좌표에서 움직이지 않는다.
func place_at(slot_line: String) -> void:
	line = slot_line
	position = BattleLayout.slot_position(slot_line)


func is_alive() -> bool:
	return hp > 0.0
