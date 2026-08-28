extends Node

## 편성. 가신을 라인 슬롯에 세운다.
##
## Phase 1 은 전/중/후 각 1칸, 총 3칸이다. 슬롯 확장은 Phase 3 백로그.
## 가신은 풀을 쓰지 않는다. 한 판에 몇 명뿐이고 끝까지 살아 있기 때문이다.
## (오브젝트 풀 대상은 적·투사체·이펙트다 — docs/ARCHITECTURE.md)

## 배치가 끝났다.
signal party_placed(units: Array)

## 인스펙터에서 scenes/entities/unit.tscn 을 연결한다.
@export var unit_scene: PackedScene

## 배치한 가신을 담을 노드. 인스펙터에서 Lanes 를 연결한다.
@export var units_root: Node2D

## 배치할 가신 ID. 라인은 heroes.json 의 line 값을 그대로 따른다.
@export var hero_ids: Array[String] = ["lien", "sera", "nina"]

## 인스펙터에서 scenes/entities/projectile.tscn 을 연결한다.
@export var projectile_scene: PackedScene

## 투사체를 담을 노드. 인스펙터에서 Projectiles 를 연결한다.
@export var projectiles_root: Node2D

## 미리 만들어 둘 투사체 수.
@export var projectile_prewarm: int = 48

var _units: Array[Unit] = []
var _by_line: Dictionary = {}   ## line → Unit


func _ready() -> void:
	if unit_scene == null:
		push_error("Party: unit_scene 이 비어 있다.")
		return
	if units_root == null:
		push_error("Party: units_root 가 비어 있다.")
		return

	if projectile_scene != null:
		ObjectPool.prewarm(projectile_scene, projectile_prewarm)

	_place_all()
	# 자식의 _ready() 가 부모보다 먼저 돈다. 부모가 연결할 틈을 준다.
	_emit_placed.call_deferred()


## 라인에 서 있는 가신. 없으면 null.
func get_unit_on_line(line: String) -> Unit:
	return _by_line.get(line, null)


## 런 내 강화를 모든 가신에게 반영한다. 라인 전용 강화는 해당 라인만 받는다.
func apply_run_upgrades(run_state: RunState) -> void:
	var atk: float = run_state.upgrade_mult("atk_mult")
	var aspd: float = run_state.upgrade_mult("atk_speed_mult")
	for u in _units:
		if not is_instance_valid(u):
			continue
		u.set_run_modifiers(
			atk,
			aspd,
			run_state.upgrade_mult("line_range_mult", u.line),
			run_state.upgrade_mult("line_hp_mult", u.line)
		)


## 살아 있는 가신 전부.
func get_alive_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in _units:
		if is_instance_valid(u) and u.is_alive():
			out.append(u)
	return out


## ---------------------------------------------------------------- 내부

func _place_all() -> void:
	for id in hero_ids:
		var data: Dictionary = DataLoader.get_hero(id)
		if data.is_empty():
			continue   # DataLoader 가 이미 오류를 찍었다

		var line: String = str(data.get("line", ""))
		if not line in BattleLayout.LINES:
			push_error("Party: '%s' 의 라인 '%s' 을 모른다." % [id, line])
			continue
		if _by_line.has(line):
			push_error("Party: %s 라인이 이미 찼다 — '%s' 를 세우지 못했다. (Phase 1 은 라인당 1칸)" % [
				line, id
			])
			continue

		var unit: Unit = unit_scene.instantiate() as Unit
		if unit == null:
			push_error("Party: unit_scene 루트에 unit.gd 가 없다.")
			return

		unit.setup(data)
		unit.set_projectile_source(projectile_scene, projectiles_root)
		units_root.add_child(unit)
		unit.place_at(line)

		unit.died.connect(_on_unit_died)
		_units.append(unit)
		_by_line[line] = unit

		print("배치 — %s(%s) %s열 %s atk=%.0f range=%.0f hp=%.0f" % [
			unit.display_name, unit.hero_id, line, unit.position, unit.atk, unit.atk_range, unit.max_hp
		])


func _on_unit_died(unit: Unit) -> void:
	print("가신 쓰러짐 — %s(%s) %s열" % [unit.display_name, unit.hero_id, unit.line])


func _emit_placed() -> void:
	party_placed.emit(_units)
