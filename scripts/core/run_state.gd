class_name RunState
extends Node

## 한 판(런)의 진행 상태. 지금 몇 층인지, 난이도가 얼마인지.
##
## Phase 1 은 seg_01(1~6층) 하나만 돈다. 심층도·영구 강화는 Phase 3 이후다.
## 런 내 강화 목록도 여기 쌓인다 — 판이 끝나면 같이 사라진다.

## 층이 바뀌었다. (층 번호, 구간 내 순번, 구간 총 층수)
signal floor_changed(floor_number: int, position: int, total: int)
## 구간의 마지막 층까지 클리어했다.
signal segment_cleared()

## 도는 구간. Phase 1 은 seg_01 뿐이다.
@export var segment_id: String = "seg_01"

var _segment: Dictionary = {}
var _floors: Array[int] = []
var _index: int = 0

## 이번 층의 배치 지형. 레인당 1줄. floors.json 의 layouts.
var _layout: Array = []

## 이번 판에 고른 강화. { upgrade_id: 스택 수 }
var _upgrades: Dictionary = {}


func _ready() -> void:
	_segment = DataLoader.get_segment(segment_id)
	if _segment.is_empty():
		push_error("RunState: 구간 '%s' 를 찾지 못했다." % segment_id)
		return

	_floors.clear()
	for f in (_segment.get("floors", []) as Array):
		_floors.append(int(f))   # JSON 숫자는 float 으로 온다
	load_layout()


## 이번 층의 지형을 읽어 둔다. 층이 바뀔 때마다 부른다.
func load_layout() -> void:
	_layout = DataLoader.get_floor_layout(current_floor())


func get_layout() -> Array:
	return _layout


## 그 타일의 종류. "ground" | "high" | "none"(막힘)
func tile_kind(lane_index: int, column_index: int) -> String:
	return BattleLayout.kind_from_layout(_layout, lane_index, column_index)


## 그 타일에 이 배치 종류를 놓을 수 있는가.
func can_place(deploy_type: String, lane_index: int, column_index: int) -> bool:
	return tile_kind(lane_index, column_index) == deploy_type


## 배치 가능한 타일 수. 지형이 좁은 층인지 판단할 때 쓴다.
func open_tile_count() -> int:
	var n: int = 0
	for li in BattleLayout.lane_count():
		for ci in BattleLayout.column_count():
			if tile_kind(li, ci) != BattleLayout.BLOCKED:
				n += 1
	return n


## 현재 층 번호 (탑 기준 절대값).
func current_floor() -> int:
	if _index < 0 or _index >= _floors.size():
		return 0
	return _floors[_index]


## 구간 안에서 몇 번째 층인가 (1-based).
func floor_position() -> int:
	return _index + 1


func total_floors() -> int:
	return _floors.size()


## 이 층이 구간 보스 층인가.
func is_boss_floor() -> bool:
	return _index == _floors.size() - 1 and not str(_segment.get("boss_hero_id", "")).is_empty()


## 보스로 나오는 가신 ID. 격파하면 해금된다.
func boss_hero_id() -> String:
	return str(_segment.get("boss_hero_id", ""))


## 보스층에 나오는 적 ID. data/enemies.json 참조.
func boss_enemy_id() -> String:
	return str(_segment.get("boss_enemy_id", ""))


## 적 체력 배수. 구간 계수 × 층당 계수^(층 순번).
func enemy_hp_mult() -> float:
	return _curve_value("enemy_hp_mult")


## 스폰 속도 배수. 클수록 빨리 나온다.
func spawn_rate_mult() -> float:
	return _curve_value("spawn_rate_mult")


## 다음 층으로. 마지막 층이었으면 false 를 주고 segment_cleared 를 쏜다.
func advance() -> bool:
	if _index + 1 >= _floors.size():
		segment_cleared.emit()
		return false
	_index += 1
	load_layout()
	_emit_floor()
	return true


## 판을 처음부터. 강화도 전부 사라진다.
func reset() -> void:
	_index = 0
	_upgrades.clear()
	load_layout()
	_emit_floor()


## 첫 층을 알린다. Battle 이 준비된 뒤 부른다.
func announce() -> void:
	_emit_floor()


## ---------------------------------------------------------------- 강화

## 런 내 강화를 하나 얻는다. 최대 스택을 넘으면 무시한다.
func add_upgrade(upgrade_id: String) -> bool:
	var row: Dictionary = DataLoader.get_upgrade(upgrade_id)
	if row.is_empty():
		return false
	var stack: int = int(_upgrades.get(upgrade_id, 0))
	if stack >= int(row.get("max_stack", 1)):
		return false
	_upgrades[upgrade_id] = stack + 1
	return true


func get_upgrade_stack(upgrade_id: String) -> int:
	return int(_upgrades.get(upgrade_id, 0))


## 고른 강화 전부. { id: 스택 }
func get_upgrades() -> Dictionary:
	return _upgrades.duplicate()


## 런 강화의 누적 배수. 같은 강화를 n번 고르면 값이 n제곱으로 곱해진다.
## deploy_type 을 주면 그 배치 종류 전용 강화만 센다 (line_hp_mult 등).
func upgrade_mult(effect_type: String, deploy_type: String = "") -> float:
	var out: float = 1.0
	for id in _upgrades:
		var e: Dictionary = DataLoader.get_upgrade(id).get("effect", {})
		if str(e.get("type", "")) != effect_type:
			continue
		if not deploy_type.is_empty() and str(e.get("deploy_type", "")) != deploy_type:
			continue
		out *= pow(float(e.get("value", 1.0)), float(_upgrades[id]))
	return out


## 런 강화의 누적 덧셈량 (aida_hp_add, element_duration_add 등).
func upgrade_add(effect_type: String) -> float:
	var out: float = 0.0
	for id in _upgrades:
		var e: Dictionary = DataLoader.get_upgrade(id).get("effect", {})
		if str(e.get("type", "")) == effect_type:
			out += float(e.get("value", 0.0)) * float(_upgrades[id])
	return out


## 3택 후보를 뽑는다. 최대 스택에 찬 것은 빠진다. 후보가 모자라면 있는 만큼만.
func roll_upgrade_choices(count: int = 3) -> Array[String]:
	var pool: Array[String] = available_upgrade_ids()
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


## 최대 스택에 도달하지 않은 강화 ID 목록. 3택 후보를 여기서 고른다.
func available_upgrade_ids() -> Array[String]:
	var out: Array[String] = []
	for id in DataLoader.ids(DataLoader.GROUP_UPGRADES):
		var row: Dictionary = DataLoader.get_upgrade(id)
		if int(_upgrades.get(id, 0)) < int(row.get("max_stack", 1)):
			out.append(id)
	return out


## ---------------------------------------------------------------- 내부

func _curve_value(key: String) -> float:
	var seg_curve: Dictionary = _segment.get("difficulty_curve", {})
	var base: float = float(seg_curve.get(key, 1.0))
	var per: float = float(DataLoader.get_per_floor_curve().get(key, 1.0))
	return base * pow(per, float(_index))


func _emit_floor() -> void:
	floor_changed.emit(current_floor(), floor_position(), total_floors())
