extends Node

## 편성과 배치. DP를 관리하고 가신을 타일에 세우거나 철수시킨다.
##
## **레퍼런스: 명일방주.** 수치와 규칙은 GDD 4.3.
##   DP 초당 1 자동 회복 / 재배치 코스트 1회차 ×1.5, 2회차부터 ×2 (상한 99)
##   철수 시 현재 코스트의 절반 환급 (내림)
##
## 재배치 코스트 상승이 핵심이다. 이게 없으면 "위험하면 뺐다 다시 넣기" 가
## 무조건 최적해가 되어 전략이 붕괴한다.
##
## 가신은 풀을 쓰지 않는다. 한 판에 몇 명뿐이고 철수해도 다시 쓰기 때문이다.

## DP가 바뀌었다. HUD 게이지가 듣는다.
signal dp_changed(dp: float, dp_max: float)
## 배치했다.
signal unit_deployed(unit: Unit, cost: int)
## 철수했다.
signal unit_retreated(hero_id: String, refund: int)
## 선봉이 처치로 DP를 벌었다. 연출·로그용.
signal dp_earned(unit: Unit, amount: float)

## 인스펙터에서 scenes/entities/unit.tscn 을 연결한다.
@export var unit_scene: PackedScene

## 배치된 가신을 담을 노드. 인스펙터에서 Units 를 연결한다.
@export var units_root: Node2D

## 인스펙터에서 scenes/entities/projectile.tscn 을 연결한다.
@export var projectile_scene: PackedScene

## 투사체를 담을 노드. 인스펙터에서 Projectiles 를 연결한다.
@export var projectiles_root: Node2D

## 미리 만들어 둘 투사체 수.
@export var projectile_prewarm: int = 48

## 손패. 이 판에 쓸 수 있는 가신 ID. Phase 1 은 8명 고정.
@export var roster: Array[String] = ["lien", "karin", "sera", "yuna", "elis", "nina", "rina", "vela"]

const FALLBACK_DP_START: float = 10.0
const FALLBACK_DP_REGEN: float = 1.0
const FALLBACK_DP_MAX: float = 99.0
const FALLBACK_LIMIT: int = 6

var _dp: float = FALLBACK_DP_START
var _dp_max: float = FALLBACK_DP_MAX
var _dp_regen: float = FALLBACK_DP_REGEN
var _deploy_limit: int = FALLBACK_LIMIT
var _redeploy_1: float = 1.5
var _redeploy_n: float = 2.0
var _cost_cap: int = 99
var _refund_ratio: float = 0.5

var _units: Array[Unit] = []          ## 지금 전장에 있는 가신
var _by_tile: Dictionary = {}         ## "lane:col" → Unit
var _deploy_count: Dictionary = {}    ## hero_id → 지금까지 배치한 횟수


func _ready() -> void:
	if unit_scene == null or units_root == null:
		push_error("Party: unit_scene 또는 units_root 가 비어 있다.")
		return

	_dp = DataLoader.get_rule("dp_start", FALLBACK_DP_START)
	_dp_max = DataLoader.get_rule("dp_max", FALLBACK_DP_MAX)
	_dp_regen = DataLoader.get_rule("dp_regen", FALLBACK_DP_REGEN)
	_deploy_limit = int(DataLoader.get_rule("deploy_limit", float(FALLBACK_LIMIT)))
	_redeploy_1 = DataLoader.get_rule("redeploy_mult_1", 1.5)
	_redeploy_n = DataLoader.get_rule("redeploy_mult_n", 2.0)
	_cost_cap = int(DataLoader.get_rule("cost_cap", 99.0))
	_refund_ratio = DataLoader.get_rule("retreat_refund", 0.5)

	if projectile_scene != null:
		ObjectPool.prewarm(projectile_scene, projectile_prewarm)

	# 자식의 _ready() 가 부모보다 먼저 돈다. HUD 가 연결할 틈을 준다.
	_announce.call_deferred()


func _process(delta: float) -> void:
	if _dp >= _dp_max:
		return
	_dp = minf(_dp_max, _dp + _dp_regen * delta)
	dp_changed.emit(_dp, _dp_max)


## ---------------------------------------------------------------- 조회

func get_dp() -> float:
	return _dp


func get_dp_max() -> float:
	return _dp_max


func get_deploy_limit() -> int:
	return _deploy_limit


func get_deployed_count() -> int:
	return _units.size()


## 지금 이 가신을 배치하는 데 드는 DP.
## 처음이면 원가, 재배치면 1.5배 → 2배. 상한 99. (명일방주 동일)
func get_cost(hero_id: String) -> int:
	var base: int = int(DataLoader.get_hero(hero_id).get("deploy_cost", 0))
	if base <= 0:
		return 0
	var times: int = int(_deploy_count.get(hero_id, 0))
	var mult: float = 1.0
	if times == 1:
		mult = _redeploy_1
	elif times >= 2:
		mult = _redeploy_n
	return mini(_cost_cap, int(floor(float(base) * mult)))


## 철수하면 돌려받는 DP.
## 보통은 현재 코스트의 절반(내림).
## **선봉(Charger)은 예외로 원가를 전액 돌려받는다.** 명일방주 동일 —
## 이게 있어야 "싸게 깔고 벌다가 빼서 딜러로 교체" 가 성립한다.
func get_refund(unit: Unit) -> int:
	if unit.refunds_full_cost():
		return int(DataLoader.get_hero(unit.hero_id).get("deploy_cost", 0))
	return int(floor(float(unit.deploy_cost) * _refund_ratio))


func is_deployed(hero_id: String) -> bool:
	for u in _units:
		if is_instance_valid(u) and u.hero_id == hero_id:
			return true
	return false


func get_unit_at(lane: String, column: int) -> Unit:
	return _by_tile.get(_key(lane, column), null)


## 그 타일에 이 가신을 놓을 수 있는가. 이유는 따지지 않고 가부만 준다.
func can_deploy(hero_id: String, lane: String, column: int) -> bool:
	return deploy_blocker(hero_id, lane, column).is_empty()


## 배치가 막히는 이유. 놓을 수 있으면 빈 문자열. UI 가 이걸 그대로 보여줄 수 있다.
func deploy_blocker(hero_id: String, lane: String, column: int) -> String:
	if not hero_id in roster:
		return "손패에 없다"
	if is_deployed(hero_id):
		return "이미 배치돼 있다"
	if _units.size() >= _deploy_limit:
		return "동시 배치 상한(%d)" % _deploy_limit
	if BattleLayout.lane_index_of(lane) < 0 or column < 0 or column >= BattleLayout.column_count():
		return "없는 타일"
	if get_unit_at(lane, column) != null:
		return "타일이 찼다"

	var data: Dictionary = DataLoader.get_hero(hero_id)
	if data.is_empty():
		return "가신 데이터 없음"
	var deploy_type: String = str(data.get("deploy_type", "ground"))
	if not BattleLayout.can_place(deploy_type, column):
		return "%s 가신은 %s 타일에만" % [
			"근접" if deploy_type == BattleLayout.GROUND else "원거리",
			"지상" if deploy_type == BattleLayout.GROUND else "고지",
		]
	if _dp < float(get_cost(hero_id)):
		return "DP 부족 (%d 필요)" % get_cost(hero_id)
	return ""


## ---------------------------------------------------------------- 배치 / 철수

## 타일에 배치한다. 실패하면 null.
func deploy(hero_id: String, lane: String, column: int) -> Unit:
	var blocker: String = deploy_blocker(hero_id, lane, column)
	if not blocker.is_empty():
		return null

	var data: Dictionary = DataLoader.get_hero(hero_id)
	var unit: Unit = unit_scene.instantiate() as Unit
	if unit == null:
		push_error("Party: unit_scene 루트에 unit.gd 가 없다.")
		return null

	var cost: int = get_cost(hero_id)
	_dp -= float(cost)

	unit.setup(data)
	unit.deploy_cost = cost   # 철수 환급은 **낸 값** 기준이다
	unit.set_projectile_source(projectile_scene, projectiles_root)
	unit.died.connect(_on_unit_died)
	units_root.add_child(unit)
	unit.place_at(lane, column)

	_units.append(unit)
	_by_tile[_key(lane, column)] = unit
	_deploy_count[hero_id] = int(_deploy_count.get(hero_id, 0)) + 1

	dp_changed.emit(_dp, _dp_max)
	unit_deployed.emit(unit, cost)
	return unit


## 철수시킨다. 돌려받은 DP를 준다. 실패하면 -1.
func retreat(unit: Unit) -> int:
	if not is_instance_valid(unit) or not unit in _units:
		return -1

	var refund: int = get_refund(unit)
	var hero_id: String = unit.hero_id

	_forget(unit)
	unit.undeploy()
	unit.queue_free()

	_dp = minf(_dp_max, _dp + float(refund))
	dp_changed.emit(_dp, _dp_max)
	unit_retreated.emit(hero_id, refund)
	return refund


## 적이 처치됐을 때 불린다. 잡은 가신이 선봉이면 DP를 준다.
func on_enemy_killed(killer_hero_id: String) -> void:
	if killer_hero_id.is_empty():
		return
	for u in _units:
		if not is_instance_valid(u) or u.hero_id != killer_hero_id:
			continue
		var gain: float = u.get_dp_on_kill()
		if gain <= 0.0:
			return
		_dp = minf(_dp_max, _dp + gain)
		dp_changed.emit(_dp, _dp_max)
		dp_earned.emit(u, gain)
		return


## ---------------------------------------------------------------- 전투 지원

## 살아 있는 가신 전부.
func get_alive_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in _units:
		if is_instance_valid(u) and u.is_alive():
			out.append(u)
	return out


## 체력 비율이 가장 낮은 지상 가신. 힐 대상이다 (GDD 4.4). 없으면 null.
func get_weakest_ground_unit() -> Unit:
	var best: Unit = null
	var best_ratio: float = 2.0
	for u in get_alive_units():
		if u.deploy_type != BattleLayout.GROUND or u.max_hp <= 0.0:
			continue
		var r: float = u.hp / u.max_hp
		if r < best_ratio:
			best_ratio = r
			best = u
	return best


## 런 내 강화를 배치된 가신 전원에게 반영한다. 배치할 때마다 다시 부른다.
func apply_run_upgrades(run_state: RunState) -> void:
	if run_state == null:
		return
	var atk: float = run_state.upgrade_mult("atk_mult")
	var aspd: float = run_state.upgrade_mult("atk_speed_mult")
	for u in _units:
		if not is_instance_valid(u):
			continue
		u.set_run_modifiers(
			atk,
			aspd,
			run_state.upgrade_mult("line_range_mult", u.deploy_type),
			run_state.upgrade_mult("line_hp_mult", u.deploy_type)
		)


## ---------------------------------------------------------------- 내부

func _key(lane: String, column: int) -> String:
	return "%s:%d" % [lane, column]


func _forget(unit: Unit) -> void:
	_units.erase(unit)
	_by_tile.erase(_key(unit.lane, unit.column))


func _on_unit_died(unit: Unit) -> void:
	print("가신 쓰러짐 — %s(%s) %s레인 열%d" % [
		unit.display_name, unit.hero_id, unit.lane, unit.column + 1
	])
	# 쓰러진 가신은 타일을 비운다. 시체가 자리를 막으면 안 된다.
	_forget(unit)
	unit.undeploy()


func _announce() -> void:
	dp_changed.emit(_dp, _dp_max)
