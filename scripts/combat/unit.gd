class_name Unit
extends Area2D

## 가신. 고정 슬롯에서 이동하지 않는다. 방향 전환도 없다.
## 스탯은 전부 data/heroes.json 에서 온다. 코드에 수치를 적지 않는다.
##
## 공격 타입 3종을 지원한다 (data/attack_types.json 의 mode).
##   nearest_single    근접. 즉시 명중. 투사체 없음
##   projectile_single 단일 사격. 투사체 1관통
##   projectile_pierce 관통 사격. max_pierce 만큼 뚫는다
##
## 타겟은 **사거리 안에서 가장 왼쪽 적**이다. 아이다에 가장 가까우니 제일 위협적이다.
## 레인과 무관하게 2D 거리로 고른다 — 전열이 붙잡은 적을 후열이 같이 때리는 재미가 여기서 나온다.

## 공격했다. 연출·로그용.
signal attacked(target: Enemy, packet: DamagePacket)

## 쓰러졌다. 저지하던 적들이 다시 전진한다.
signal died(unit: Unit)

## 고유 스킬이 발동했다. DP 획득처럼 밖에서 처리할 효과는 여기로 나간다.
signal skill_activated(unit: Unit, skill: Dictionary)

## setup() 전에 참조될 때만 쓰는 대비값.
const FALLBACK_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const FALLBACK_CRIT_MULT: float = 2.0
const FALLBACK_PROJECTILE_SPEED: float = 600.0
const FALLBACK_MIN_DAMAGE: float = 1.0

## 전장에 세울 때의 목표 키(픽셀). 레인 간격 112 보다 작아야 세로로 겹치지 않는다.
const SPRITE_HEIGHT: float = 100.0


## 레인별 그룹 이름. 적이 자기 레인의 가신을 찾을 때 쓴다.
static func lane_group(lane: String) -> StringName:
	return StringName("unit_lane_" + lane)

var hero_id: String = ""
var display_name: String = ""

## ground(지상·근접) | high(고지·원거리)
var deploy_type: String = "ground"

## 배치에 든 DP. 재배치 코스트 계산과 철수 환급에 쓴다.
var deploy_cost: int = 0

## 배치된 타일. lane 은 "a"/"b"/"c", column 은 0~2.
var lane: String = ""
var column: int = -1
var attack_type_id: String = ""
var skill_id: String = ""

var max_hp: float = 0.0
var hp: float = 0.0
var atk: float = 0.0
var atk_speed: float = 1.0
var atk_range: float = 0.0    ## range 는 GDScript 내장 함수 이름이라 못 쓴다
var crit: float = 0.0
var defense: float = 0.0

## 동시에 저지할 수 있는 적 수. 0이면 저지하지 않는다 (원거리 가신).
var block_count: int = 0

## 특성. heroes.json 의 traits 블록이 그대로 온다.
##   dp_on_kill        처치할 때마다 얻는 DP (명일방주 Charger)
##   refund_full_cost  철수 시 현재 코스트의 절반이 아니라 **원가 전액** 환급 (Charger)
var traits: Dictionary = {}

## 런 내 강화의 누적 계수. 아이다 버프와 달리 판이 끝날 때까지 유지된다.
var run_atk_mult: float = 1.0
var run_atk_speed_mult: float = 1.0
var run_range_mult: float = 1.0

var _base_max_hp: float = 0.0

var _attack_mode: String = ""
var _attack_params: Dictionary = {}
var _crit_mult: float = FALLBACK_CRIT_MULT
var _cooldown: float = 0.0

## Party 가 넣어 준다. 투사체를 쓰지 않는 근접 가신은 없어도 된다.
var _projectile_scene: PackedScene = null
var _projectiles_root: Node2D = null

var _min_damage: float = FALLBACK_MIN_DAMAGE
var _blockers: Array[Enemy] = []

## 고유 스킬. scripts/combat/unit_skill.gd
var _skill: UnitSkill = UnitSkill.new()

## 겉모습(스프라이트 교체·체력바). scripts/combat/unit_visual.gd
var _visual: UnitVisual = UnitVisual.new()

## 버프와 부여 속성. 순수 계산이라 따로 뺐다. scripts/combat/stat_mods.gd
var _mods: StatMods = StatMods.new()


## data/heroes.json 의 항목 하나를 받아 스탯과 외형을 세팅한다.
## 레벨 성장(growth)은 Phase 1 범위 밖이라 base_stats 를 그대로 쓴다.
func setup(data: Dictionary) -> void:
	if data.is_empty():
		push_error("Unit.setup: 빈 데이터가 들어왔다.")
		return

	hero_id = str(data.get("id", ""))
	display_name = str(data.get("name", hero_id))
	deploy_type = str(data.get("deploy_type", "ground"))
	deploy_cost = int(data.get("deploy_cost", 0))
	attack_type_id = str(data.get("attack_type_id", ""))
	skill_id = str(data.get("skill_id", ""))

	var stats: Dictionary = data.get("base_stats", {})
	max_hp = float(stats.get("hp", 1.0))
	_base_max_hp = max_hp
	hp = max_hp
	atk = float(stats.get("atk", 0.0))
	atk_speed = float(stats.get("atk_speed", 1.0))
	atk_range = float(stats.get("range", 0.0))
	crit = float(stats.get("crit", 0.0))
	defense = float(stats.get("defense", 0.0))
	block_count = int(stats.get("block_count", 0))
	traits = data.get("traits", {})
	_skill.setup(str(data.get("skill_id", "")))
	if not _skill.activated.is_connected(_on_skill_activated):
		_skill.activated.connect(_on_skill_activated)
	_mods.clear()
	_min_damage = DataLoader.get_rule("min_damage", FALLBACK_MIN_DAMAGE)
	_blockers.clear()
	var atype: Dictionary = DataLoader.get_attack_type(attack_type_id)
	_attack_mode = str(atype.get("mode", ""))
	_attack_params = atype.get("params", {})
	_crit_mult = DataLoader.get_rule("crit_mult", FALLBACK_CRIT_MULT)
	_cooldown = 0.0

	_visual.setup(self, data, SPRITE_HEIGHT)
	_refresh_bar()


## Party 가 투사체 발사에 필요한 것을 넣어 준다.
func set_projectile_source(scene: PackedScene, root: Node2D) -> void:
	_projectile_scene = scene
	_projectiles_root = root


## 체력바를 현재 체력에 맞춘다.
func _refresh_bar() -> void:
	if max_hp > 0.0:
		_visual.set_hp_ratio(hp / max_hp)


## 타일에 세운다. 이후 이 좌표에서 움직이지 않는다.
func place_at(tile_lane: String, tile_column: int) -> void:
	lane = tile_lane
	column = tile_column
	position = BattleLayout.tile_position(BattleLayout.lane_index_of(lane), column)
	# 같은 레인의 적이 찾을 수 있도록 레인 그룹에 들어간다.
	var g: StringName = lane_group(lane)
	if not is_in_group(g):
		add_to_group(g)


## 철수. 그룹에서 빠지고 저지하던 적을 놓아 준다.
func undeploy() -> void:
	var g: StringName = lane_group(lane)
	if is_in_group(g):
		remove_from_group(g)
	_release_all_blockers()


## ---------------------------------------------------------------- 고유 스킬

## 스킬 발동 시 즉발 효과를 처리한다. 지속형은 UnitSkill 이 시간을 센다.
func _on_skill_activated(skill: Dictionary) -> void:
	var effect: Dictionary = skill.get("effect", {})
	var duration: float = float(skill.get("duration", 0.0))

	match str(effect.get("type", "")):
		"atk_mult":
			apply_buff("atk_mult", float(effect.get("value", 1.0)), duration)
		"block_up":
			_skill.begin_duration(
				int(effect.get("block_add", 0)),
				float(effect.get("defense_mult", 1.0)),
				duration
			)
		"burst_range":
			_burst_range(float(effect.get("mult", 1.0)))
		"dp_gain":
			pass   # DP 는 Party 가 준다. 아래 시그널로 넘어간다
		_:
			push_error("Unit: 모르는 스킬 효과 '%s' (%s)" % [effect.get("type", ""), hero_id])

	Effects.skill_popup(position + Vector2(0.0, -SPRITE_HEIGHT - 26.0), _skill.get_name())
	skill_activated.emit(self, skill)


## 사거리 안의 모든 적을 한 번에 때린다. 즉발.
func _burst_range(mult: float) -> void:
	var r: float = get_range()
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if position.distance_to(enemy.position) > r:
			continue
		var packet := DamagePacket.new(get_atk() * mult, false, hero_id)
		packet.element = _mods.get_element()
		packet.element_params = _mods.get_element_params()
		enemy.take_damage(packet)


func is_skill_active() -> bool:
	return _skill.is_active()


## SP 충전률 0~1.
func get_sp_ratio() -> float:
	return _skill.get_ratio()


## ---------------------------------------------------------------- 버프 / 속성

## 아이다 버프를 건다.
func apply_buff(type: String, value: float, duration: float) -> void:
	_mods.add_buff(type, value, duration)


## 속성을 부여한다. 이후 이 가신의 공격에 element 와 그 수치가 실린다.
func apply_element(element: String, duration: float, params: Dictionary) -> void:
	_mods.set_element(element, duration, params)


func get_element_color() -> String:
	return _mods.get_element_color()


## 버프가 적용된 실효 수치. 공격 로직은 반드시 이 getter 를 쓴다.
func get_atk() -> float:
	return atk * _mods.mult_of("atk_mult") * run_atk_mult


func get_atk_speed() -> float:
	return atk_speed * _mods.mult_of("atk_speed_mult") * run_atk_speed_mult


func get_crit() -> float:
	return clampf(crit + _mods.sum_of("crit_add"), 0.0, 1.0)


func get_range() -> float:
	return atk_range * _mods.mult_of("range_mult") * run_range_mult


func get_element() -> String:
	return _mods.get_element()


## 스킬로 늘어난 저지 수를 포함한 실효 저지 수.
func get_block_count() -> int:
	return block_count + _skill.block_bonus


## 스킬로 오른 방어력.
func get_defense() -> float:
	return defense * _skill.defense_mult


func has_buff() -> bool:
	return _mods.has_buff()


## 런 내 강화를 반영한다. 누적값을 통째로 다시 넣는 방식이라 여러 번 불러도 안전하다.
## 체력 상한이 오르면 오른 만큼 회복시킨다 — 안 그러면 고른 보람이 없다.
func set_run_modifiers(atk_mult: float, aspd_mult: float, range_mult: float, hp_mult: float) -> void:
	run_atk_mult = atk_mult
	run_atk_speed_mult = aspd_mult
	run_range_mult = range_mult

	var new_max: float = _base_max_hp * hp_mult
	if not is_equal_approx(new_max, max_hp):
		var gained: float = new_max - max_hp
		max_hp = new_max
		if gained > 0.0:
			hp = minf(max_hp, hp + gained)
		else:
			hp = minf(hp, max_hp)
		_refresh_bar()


## ---------------------------------------------------------------- 저지

## 적이 저지를 요청한다. 자리가 있으면 받아 준다.
func try_block(enemy: Enemy) -> bool:
	if not is_alive() or _blockers.size() >= get_block_count():
		return false
	if enemy in _blockers:
		return true
	_blockers.append(enemy)
	return true


## 저지 해제. 적이 죽거나 풀에 반납될 때 스스로 부른다.
func release_block(enemy: Enemy) -> void:
	_blockers.erase(enemy)


func get_block_load() -> int:
	return _blockers.size()


## ---------------------------------------------------------------- 피해

## 저지 중인 적에게 맞는다. 방어력은 맞는 쪽이 뺀다.
func take_damage(packet: DamagePacket) -> void:
	if packet == null or not is_alive():
		return

	var dealt: float = maxf(_min_damage, packet.base - get_defense())
	hp -= dealt
	_skill.gain("hit", 1.0)
	_refresh_bar()

	if not packet.silent_number:
		var at: Vector2 = position + Vector2(0.0, -SPRITE_HEIGHT * 0.55)
		Effects.damage(at, dealt, Effects.COLOR_ALLY_HIT, false)
		Effects.hit(at, Effects.COLOR_ALLY_HIT)

	if hp <= 0.0:
		hp = 0.0
		Effects.kill(position + Vector2(0.0, -SPRITE_HEIGHT * 0.55), Effects.COLOR_ALLY_HIT)
		_die()


## 회복. 최대치를 넘지 않는다.
func heal(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	_refresh_bar()


func _die() -> void:
	_visual.mark_dead()
	_release_all_blockers()
	died.emit(self)


## 붙잡고 있던 적들을 놓아 준다. 순회 중 배열이 바뀌므로 복사본을 돈다.
func _release_all_blockers() -> void:
	var held: Array[Enemy] = _blockers.duplicate()
	_blockers.clear()
	for e in held:
		if is_instance_valid(e):
			e.on_blocker_lost()


func is_alive() -> bool:
	return hp > 0.0


## 처치 시 벌어들이는 DP. 선봉이 아니면 0.
func get_dp_on_kill() -> float:
	return float(traits.get("dp_on_kill", 0.0))


## 철수 시 원가를 전부 돌려받는가. 명일방주 Charger 특성.
func refunds_full_cost() -> bool:
	return bool(traits.get("refund_full_cost", false))


func _process(delta: float) -> void:
	if not is_alive():
		return

	_mods.tick(delta)
	_visual.tick(delta)
	_skill.tick(delta)

	if _attack_mode.is_empty():
		return

	_cooldown -= delta
	if _cooldown > 0.0:
		return

	var target: Enemy = _find_target()
	if target == null:
		return

	_attack(target)
	_cooldown = 1.0 / maxf(get_atk_speed(), 0.01)


## ---------------------------------------------------------------- 내부

## 사거리 안에서 가장 왼쪽 적. 없으면 null.
func _find_target() -> Enemy:
	var best: Enemy = null
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if position.distance_to(enemy.position) > get_range():
			continue
		if best == null or enemy.position.x < best.position.x:
			best = enemy
	return best


func _attack(target: Enemy) -> void:
	var packet: DamagePacket = _make_packet()

	match _attack_mode:
		"nearest_single":
			target.take_damage(packet)
		"projectile_single":
			_fire_projectile(packet, 1)
		"projectile_pierce":
			_fire_projectile(packet, int(_attack_params.get("max_pierce", 1)))
		_:
			push_error("Unit: 아직 구현하지 않은 공격 모드 '%s' (%s)" % [_attack_mode, hero_id])
			return

	_skill.gain("attack", 1.0)
	_visual.show_attack()
	attacked.emit(target, packet)


## 치명타는 발사 시점에 한 번만 굴린다. 관통이라도 맞는 적마다 다시 굴리지 않는다.
func _make_packet() -> DamagePacket:
	var is_crit: bool = randf() < get_crit()
	var base: float = get_atk() * (_crit_mult if is_crit else 1.0)
	var packet := DamagePacket.new(base, is_crit, hero_id)
	packet.element = _mods.get_element()
	packet.element_params = _mods.get_element_params()
	return packet


func _fire_projectile(packet: DamagePacket, pierce: int) -> void:
	if _projectile_scene == null or _projectiles_root == null:
		push_error("Unit: 투사체 설정이 없다 — Party 가 set_projectile_source() 를 부르지 않았다.")
		return

	var shot: Projectile = ObjectPool.acquire(_projectile_scene) as Projectile
	if shot == null:
		push_error("Unit: projectile_scene 루트에 projectile.gd 가 없다.")
		return

	# 속성이 실렸으면 속성색으로, 아니면 쏜 가신의 색으로. 눌렀는지 화면만 봐도 알아야 한다.
	var tint: String = get_element_color()
	shot.modulate = Color.from_string(tint, modulate) if not tint.is_empty() else modulate
	_projectiles_root.add_child(shot)
	shot.launch(position, packet, float(_attack_params.get("speed", FALLBACK_PROJECTILE_SPEED)), pierce)
