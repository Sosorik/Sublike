extends Node

## data/*.json 로더. 게임 시작 시 1회 읽고 캐시한다.
## autoload 이름: DataLoader (그래서 class_name 을 쓰지 않는다 — 이름이 충돌한다)
##
## 캐시 원본은 밖으로 내보내지 않는다. 모든 접근자는 깊은 복사본을 돌려준다.
## 런타임에서 수치를 깎거나 곱해도 원본 JSON 값은 그대로 남는다.
## (docs/ARCHITECTURE.md "데이터 흐름")

## 모든 파일을 읽고 색인까지 끝냈다.
signal data_loaded()

const GROUP_HEROES: String = "heroes"
const GROUP_ENEMIES: String = "enemies"
const GROUP_ATTACK_TYPES: String = "attack_types"
const GROUP_HERO_SKILLS: String = "hero_skills"
const GROUP_AIDA_SKILLS: String = "aida_skills"
const GROUP_UPGRADES: String = "run_upgrades"
const GROUP_SEGMENTS: String = "segments"
const GROUP_COMBAT_RULES: String = "combat_rules"
const GROUP_AIDA: String = "aida"

## 그룹 → { 파일 경로, 배열이 담긴 최상위 키 }.
## 새 데이터 파일이 생기면 여기 한 줄만 추가한다.
const SOURCES: Dictionary = {
	GROUP_HEROES: { "path": "res://data/heroes.json", "key": "heroes" },
	GROUP_ENEMIES: { "path": "res://data/enemies.json", "key": "enemies" },
	GROUP_ATTACK_TYPES: { "path": "res://data/attack_types.json", "key": "attack_types" },
	GROUP_HERO_SKILLS: { "path": "res://data/hero_skills.json", "key": "hero_skills" },
	GROUP_AIDA_SKILLS: { "path": "res://data/aida_skills.json", "key": "skills" },
	GROUP_UPGRADES: { "path": "res://data/run_upgrades.json", "key": "upgrades" },
	GROUP_SEGMENTS: { "path": "res://data/floors.json", "key": "segments" },
	GROUP_COMBAT_RULES: { "path": "res://data/combat_rules.json", "key": "rules" },
	GROUP_AIDA: { "path": "res://data/aida.json", "key": "aida" },
}

## id가 이 접두어로 시작하면 주석·템플릿이므로 색인에서 뺀다. (heroes.json 의 "_template")
const SKIP_PREFIX: String = "_"

## 모든 파일이 정상적으로 읽혔다. false면 데이터가 깨진 것이니 전투를 시작하면 안 된다.
var is_loaded: bool = false

var _raw: Dictionary = {}     ## 그룹 → 파일 전체 Dictionary
var _index: Dictionary = {}   ## 그룹 → { id: 항목 Dictionary }
var _order: Dictionary = {}   ## 그룹 → [id]. JSON에 적힌 순서를 유지한다


func _ready() -> void:
	load_all()


## 전체 재로드. 데이터를 고치고 다시 읽고 싶을 때도 쓴다.
func load_all() -> void:
	_raw.clear()
	_index.clear()
	_order.clear()

	var ok: bool = true
	for group in SOURCES:
		if not _load_group(group, SOURCES[group]):
			ok = false

	is_loaded = ok
	if ok:
		data_loaded.emit()
	else:
		push_error("DataLoader: 데이터 로드 실패. 위 오류를 먼저 고칠 것.")


## ---------------------------------------------------------------- 조회

## 그룹에서 id로 항목 하나. 없으면 빈 Dictionary + 오류 로그.
func get_entry(group: String, id: String) -> Dictionary:
	var table: Dictionary = _index.get(group, {})
	if not table.has(id):
		push_error("DataLoader: %s 에 '%s' 가 없다." % [group, id])
		return {}
	return (table[id] as Dictionary).duplicate(true)


## 그룹 전체를 JSON 순서대로. 템플릿 항목은 빠져 있다.
func get_all(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var table: Dictionary = _index.get(group, {})
	for id in _order.get(group, [] as Array[String]):
		out.append((table[id] as Dictionary).duplicate(true))
	return out


func has_entry(group: String, id: String) -> bool:
	return (_index.get(group, {}) as Dictionary).has(id)


## 그룹의 id 목록. JSON 순서.
func ids(group: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(_order.get(group, [] as Array[String]))
	return out


func count(group: String) -> int:
	return (_index.get(group, {}) as Dictionary).size()


## ---------------------------------------------------------------- 편의 접근자

func get_hero(id: String) -> Dictionary:
	return get_entry(GROUP_HEROES, id)


func get_enemy(id: String) -> Dictionary:
	return get_entry(GROUP_ENEMIES, id)


func get_attack_type(id: String) -> Dictionary:
	return get_entry(GROUP_ATTACK_TYPES, id)


func get_hero_skill(id: String) -> Dictionary:
	return get_entry(GROUP_HERO_SKILLS, id)


func get_aida_skill(id: String) -> Dictionary:
	return get_entry(GROUP_AIDA_SKILLS, id)


func get_upgrade(id: String) -> Dictionary:
	return get_entry(GROUP_UPGRADES, id)


func get_segment(id: String) -> Dictionary:
	return get_entry(GROUP_SEGMENTS, id)


## 아이다 본인의 데이터. data/aida.json 참조.
func get_aida() -> Dictionary:
	return get_entry(GROUP_AIDA, "aida")


## 전투 공통 수치 하나. data/combat_rules.json 참조.
## 없으면 default 를 돌려주고 오류를 찍지 않는다 (호출부에 대비값이 있다는 뜻).
func get_rule(id: String, default_value: float) -> float:
	var table: Dictionary = _index.get(GROUP_COMBAT_RULES, {})
	if not table.has(id):
		return default_value
	return float((table[id] as Dictionary).get("value", default_value))


## 웨이브 스포너 설정. enemies.json 의 wave_pattern 블록.
func get_wave_pattern() -> Dictionary:
	var doc: Dictionary = _raw.get(GROUP_ENEMIES, {})
	var pattern: Variant = doc.get("wave_pattern")
	if typeof(pattern) != TYPE_DICTIONARY:
		push_error("DataLoader: enemies.json 에 wave_pattern 이 없다.")
		return {}
	return (pattern as Dictionary).duplicate(true)


## 층별 배치 지형. 없으면 default. floors.json 의 layouts 참조.
func get_floor_layout(floor_number: int) -> Array:
	var doc: Dictionary = _raw.get(GROUP_SEGMENTS, {})
	var table: Variant = doc.get("layouts")
	if typeof(table) != TYPE_DICTIONARY:
		return []
	var t: Dictionary = table
	var key: String = str(floor_number)
	var rows: Variant = t.get(key, t.get("default", []))
	return (rows as Array).duplicate() if typeof(rows) == TYPE_ARRAY else []


## 구간 안에서 층이 오를 때마다 곱해지는 난이도 계수. floors.json 참조.
func get_per_floor_curve() -> Dictionary:
	var doc: Dictionary = _raw.get(GROUP_SEGMENTS, {})
	var curve: Variant = doc.get("per_floor_curve")
	if typeof(curve) != TYPE_DICTIONARY:
		return {}
	return (curve as Dictionary).duplicate(true)


## 해당 층이 속한 구간. 없으면 빈 Dictionary.
##
## JSON의 숫자는 전부 float으로 들어온다. Array.has()는 타입까지 따지므로
## `6 in [1.0, 2.0, ...]` 는 false다. 반드시 int()로 맞춰 비교한다.
func get_segment_of_floor(floor_number: int) -> Dictionary:
	var table: Dictionary = _index.get(GROUP_SEGMENTS, {})
	for id in _order.get(GROUP_SEGMENTS, [] as Array[String]):
		var seg: Dictionary = table[id]
		for f in (seg.get("floors", []) as Array):
			if int(f) == floor_number:
				return seg.duplicate(true)
	push_error("DataLoader: %d층이 속한 구간이 없다." % floor_number)
	return {}


## ---------------------------------------------------------------- 내부

func _load_group(group: String, source: Dictionary) -> bool:
	var path: String = source["path"]
	var key: String = source["key"]

	if not FileAccess.file_exists(path):
		push_error("DataLoader: 파일이 없다 — %s" % path)
		return false

	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("DataLoader: 파일이 비었거나 읽지 못했다 — %s" % path)
		return false

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_error("DataLoader: JSON 파싱 실패 — %s (%d행) %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return false

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("DataLoader: 최상위가 객체가 아니다 — %s" % path)
		return false

	var doc: Dictionary = json.data
	if typeof(doc.get(key)) != TYPE_ARRAY:
		push_error("DataLoader: '%s' 배열이 없다 — %s" % [key, path])
		return false

	var table: Dictionary = {}
	var order: Array[String] = []
	for row in (doc[key] as Array):
		if typeof(row) != TYPE_DICTIONARY:
			push_error("DataLoader: %s 의 항목이 객체가 아니다 — %s" % [key, path])
			return false
		var entry: Dictionary = row
		var id: String = str(entry.get("id", ""))
		if id.is_empty():
			push_error("DataLoader: id 없는 항목이 있다 — %s" % path)
			return false
		if id.begins_with(SKIP_PREFIX):
			continue
		if table.has(id):
			push_error("DataLoader: id 중복 '%s' — %s" % [id, path])
			return false
		table[id] = entry
		order.append(id)

	_raw[group] = doc
	_index[group] = table
	_order[group] = order
	return true
