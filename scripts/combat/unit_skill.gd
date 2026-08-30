class_name UnitSkill
extends RefCounted

## 가신 고유 스킬. **명일방주 방식** — SP 가 차면 자동으로 터진다.
##
## 아이다 버튼 3개라는 조작 원칙(GDD 4.4)을 지키려고 수동 발동은 두지 않는다.
## 가신이 8명인데 각자 버튼을 가지면 "한 손 조작" 이 무너진다.
##
## SP 충전 방식 3종은 명일방주 그대로다.
##   auto    초당 1
##   attack  공격할 때마다 1
##   hit     맞을 때마다 1
##
## unit.gd 가 500줄을 넘어서 떼어냈다 (CLAUDE.md 금지 항목).

## 스킬이 터졌다. (스킬 데이터)
signal activated(skill: Dictionary)

var data: Dictionary = {}

## 지속형 효과가 남긴 값. 끝나면 0 / 1.0 으로 돌아온다.
var block_bonus: int = 0
var defense_mult: float = 1.0

var _sp: float = 0.0
var _sp_cost: float = 0.0
var _recovery: String = "auto"
var _left: float = 0.0


## 가신 데이터의 skill_id 로 준비한다. 배치될 때마다 부른다.
func setup(skill_id: String) -> void:
	data = DataLoader.get_hero_skill(skill_id) if not skill_id.is_empty() else {}
	block_bonus = 0
	defense_mult = 1.0
	_left = 0.0
	if data.is_empty():
		_sp = 0.0
		_sp_cost = 0.0
		return
	_sp_cost = float(data.get("sp_cost", 0.0))
	_recovery = str(data.get("sp_recovery", "auto"))
	_sp = float(data.get("sp_initial", 0.0))


## SP 를 채운다. 충전 방식이 맞을 때만, 그리고 스킬이 도는 중이 아닐 때만.
func gain(source: String, amount: float) -> void:
	if data.is_empty() or _recovery != source or _left > 0.0:
		return
	_sp = minf(_sp_cost, _sp + amount)


## 시간을 흘린다. 다 차면 activated 를 쏜다. 지속형이면 남은 시간을 깎는다.
func tick(delta: float) -> void:
	if data.is_empty():
		return

	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			block_bonus = 0
			defense_mult = 1.0
		return

	gain("auto", delta)
	if _sp_cost > 0.0 and _sp >= _sp_cost:
		_fire()


func is_active() -> bool:
	return _left > 0.0


## SP 충전률 0~1.
func get_ratio() -> float:
	return clampf(_sp / _sp_cost, 0.0, 1.0) if _sp_cost > 0.0 else 0.0


func get_name() -> String:
	return str(data.get("name", ""))


func get_effect() -> Dictionary:
	return data.get("effect", {})


## 지속형 효과를 켠다. 즉발 효과는 Unit 이 처리한다.
func begin_duration(add_block: int, mult_defense: float, duration: float) -> void:
	block_bonus = add_block
	defense_mult = mult_defense
	_left = duration


func _fire() -> void:
	_sp = 0.0
	activated.emit(data)
