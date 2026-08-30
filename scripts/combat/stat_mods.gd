class_name StatMods
extends RefCounted

## 유닛에 걸린 일시 효과 모음. 버프와 부여된 속성.
##
## Unit 에서 떼어낸 이유는 두 가지다.
##   1. unit.gd 가 500줄을 넘었다 (CLAUDE.md 금지 항목)
##   2. 이 덩어리는 트리도 씬도 안 쓴다. 순수 계산이라 따로 두는 게 맞다
##
## 기본 스탯은 절대 건드리지 않는다. 배수를 곱해 돌려줄 뿐이다.
## 그래야 버프가 꼬여도 원래 수치가 망가지지 않는다.

## 걸린 버프. 각 항목 { type, value, remaining }.
var _buffs: Array[Dictionary] = []

## 부여된 속성. "" 면 무속성.
var _element: String = ""
var _element_left: float = 0.0
var _element_params: Dictionary = {}


func clear() -> void:
	_buffs.clear()
	_element = ""
	_element_left = 0.0
	_element_params = {}


## 버프를 건다. 같은 종류가 겹치면 곱해진다.
func add_buff(type: String, value: float, duration: float) -> void:
	_buffs.append({ "type": type, "value": value, "remaining": duration })


## 속성을 부여한다. params 는 aida_skills.json 의 effect 블록이다.
func set_element(element: String, duration: float, params: Dictionary) -> void:
	_element = element
	_element_left = maxf(_element_left, duration)
	_element_params = params


func get_element() -> String:
	return _element


func get_element_params() -> Dictionary:
	return _element_params


## 부여된 속성의 표시색. 없으면 빈 문자열.
func get_element_color() -> String:
	return str(_element_params.get("vfx_color", ""))


func has_buff() -> bool:
	return not _buffs.is_empty()


## 그 종류 버프들의 곱. 없으면 1.0.
func mult_of(type: String) -> float:
	var out: float = 1.0
	for b in _buffs:
		if b["type"] == type:
			out *= float(b["value"])
	return out


## 그 종류 버프들의 합. 없으면 0.0.
func sum_of(type: String) -> float:
	var out: float = 0.0
	for b in _buffs:
		if b["type"] == type:
			out += float(b["value"])
	return out


## 지속시간을 깎고 끝난 것을 버린다.
func tick(delta: float) -> void:
	if not _buffs.is_empty():
		for i in range(_buffs.size() - 1, -1, -1):
			_buffs[i]["remaining"] = float(_buffs[i]["remaining"]) - delta
			if float(_buffs[i]["remaining"]) <= 0.0:
				_buffs.remove_at(i)

	if _element_left > 0.0:
		_element_left -= delta
		if _element_left <= 0.0:
			_element = ""
			_element_params = {}
