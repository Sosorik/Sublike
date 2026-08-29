class_name AidaSkills
extends Node

## 아이다의 액티브 스킬 슬롯 3개 (buff / element / heal).
## 아이다의 조작은 이 버튼 3개뿐이다. 이동도 없고 수동 공격도 없다.
##
## 장착 스킬은 data/aida_skills.json 에서 온다. 해금한 가신이 전수하는 구조는
## GameState 가 생기면 그쪽으로 옮긴다. 지금은 인스펙터에 직접 적는다.

## 스킬을 썼다. 컷인 연출이 이걸 듣는다.
signal skill_used(slot: int, skill: Dictionary)
## 쿨타임이 바뀌었다. HUD 게이지가 이걸 듣는다.
signal cooldown_changed(slot: int, remaining: float, total: float)
## 자동 시전 토글이 바뀌었다.
signal auto_cast_changed(enabled: bool)

## 슬롯 순서. HUD 버튼 순서와 같다.
const SLOTS: Array[String] = ["buff", "element", "heal"]

## 슬롯에 장착한 스킬 ID. 순서는 SLOTS 와 맞춘다.
@export var skill_ids: Array[String] = ["buff_power", "elem_fire", "heal_instant"]

## 인스펙터에서 Party 를 연결한다. 버프·속성이 가신에게 간다.
@export var party: Node

## 인스펙터에서 Aida 를 연결한다. 힐이 아이다에게 간다.
@export var aida: Aida

## 켜면 쿨타임이 도는 대로 알아서 쓴다.
@export var auto_cast: bool = false

var _skills: Array[Dictionary] = []
var _cooldowns: Array[float] = []

## 런 내 강화 누적값.
var _run_cooldown_mult: float = 1.0
var _run_element_add: float = 0.0
var _run_heal_mult: float = 1.0


func _ready() -> void:
	if party == null or aida == null:
		push_error("AidaSkills: party 또는 aida 가 비어 있다.")
		return

	for i in SLOTS.size():
		var id: String = skill_ids[i] if i < skill_ids.size() else ""
		var skill: Dictionary = DataLoader.get_aida_skill(id) if not id.is_empty() else {}
		if not skill.is_empty() and str(skill.get("slot", "")) != SLOTS[i]:
			push_error("AidaSkills: '%s' 는 %s 슬롯 스킬이 아니다 (%s)." % [
				id, SLOTS[i], skill.get("slot", "")
			])
			skill = {}
		_skills.append(skill)
		_cooldowns.append(0.0)

	# 자식의 _ready() 가 부모보다 먼저 돈다. HUD 가 연결할 틈을 준다.
	_announce.call_deferred()


func _process(delta: float) -> void:
	for i in _cooldowns.size():
		if _cooldowns[i] <= 0.0:
			continue
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
		cooldown_changed.emit(i, _cooldowns[i], _total_cooldown(i))

	if auto_cast:
		for i in _skills.size():
			if is_ready(i):
				try_use(i)


## 슬롯의 스킬. 비어 있을 수 있다.
func get_skill(slot: int) -> Dictionary:
	if slot < 0 or slot >= _skills.size():
		return {}
	return _skills[slot]


func is_ready(slot: int) -> bool:
	if slot < 0 or slot >= _skills.size():
		return false
	return not _skills[slot].is_empty() and _cooldowns[slot] <= 0.0


func get_cooldown(slot: int) -> float:
	return _cooldowns[slot] if slot >= 0 and slot < _cooldowns.size() else 0.0


## 스킬을 쓴다. 쿨타임이 남았으면 아무 일도 없다.
func try_use(slot: int) -> bool:
	if not is_ready(slot):
		return false
	if not aida.is_alive():
		return false

	var skill: Dictionary = _skills[slot]
	_apply(skill)

	_cooldowns[slot] = _total_cooldown(slot)
	cooldown_changed.emit(slot, _cooldowns[slot], _total_cooldown(slot))
	skill_used.emit(slot, skill)
	return true


## 런 내 강화를 반영한다. 누적값을 통째로 넣는 방식이라 여러 번 불러도 안전하다.
func set_run_modifiers(cooldown_mult: float, element_add: float, heal_mult: float) -> void:
	_run_cooldown_mult = cooldown_mult
	_run_element_add = element_add
	_run_heal_mult = heal_mult
	for i in _cooldowns.size():
		cooldown_changed.emit(i, _cooldowns[i], _total_cooldown(i))


func set_auto_cast(enabled: bool) -> void:
	if auto_cast == enabled:
		return
	auto_cast = enabled
	auto_cast_changed.emit(auto_cast)


func toggle_auto_cast() -> void:
	set_auto_cast(not auto_cast)


## ---------------------------------------------------------------- 내부

func _total_cooldown(slot: int) -> float:
	if _skills[slot].is_empty():
		return 1.0
	return maxf(0.5, float(_skills[slot].get("cooldown", 1.0)) * _run_cooldown_mult)


func _apply(skill: Dictionary) -> void:
	var effect: Dictionary = skill.get("effect", {})
	var type: String = str(effect.get("type", ""))
	var value: float = float(effect.get("value", 0.0))
	var duration: float = float(skill.get("duration", 0.0))

	match type:
		"atk_mult", "atk_speed_mult", "crit_add", "range_mult":
			for u in party.get_alive_units():
				u.apply_buff(type, value, duration)
		"dot", "slow", "chain", "ignore_defense":
			# 속성 부여. 가신의 공격에 속성이 실린다. 실제 효과는 맞는 쪽이 처리한다.
			var element: String = str(skill.get("element", ""))
			if element.is_empty():
				push_error("AidaSkills: '%s' 에 element 가 없다." % skill.get("id", ""))
				return
			# effect 를 그대로 넘긴다. 지속시간도 같이 실어서 맞는 쪽이 알 수 있게 한다.
			# 속성 지속 강화는 부여 시간과 맞은 뒤 타는 시간 둘 다에 붙는다.
			var elem_dur: float = duration + _run_element_add
			var params: Dictionary = effect.duplicate(true)
			params["duration"] = elem_dur
			for u in party.get_alive_units():
				u.apply_element(element, elem_dur, params)
		"heal_flat":
			# GDD 4.4 — 힐 대상은 아이다 본인 + 체력 비율이 가장 낮은 지상 가신.
			var amount: float = value * _run_heal_mult
			aida.heal(amount)
			var hurt: Unit = party.get_weakest_ground_unit()
			if hurt != null:
				hurt.heal(amount)
		_:
			push_error("AidaSkills: 아직 구현하지 않은 효과 '%s' (%s)" % [type, skill.get("id", "")])


func _announce() -> void:
	for i in _skills.size():
		cooldown_changed.emit(i, _cooldowns[i], _total_cooldown(i))
	auto_cast_changed.emit(auto_cast)
