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

## setup() 전에 참조될 때만 쓰는 대비값.
const FALLBACK_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const FALLBACK_CRIT_MULT: float = 2.0
const FALLBACK_PROJECTILE_SPEED: float = 600.0

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

var _attack_mode: String = ""
var _attack_params: Dictionary = {}
var _crit_mult: float = FALLBACK_CRIT_MULT
var _cooldown: float = 0.0

## Party 가 넣어 준다. 투사체를 쓰지 않는 근접 가신은 없어도 된다.
var _projectile_scene: PackedScene = null
var _projectiles_root: Node2D = null


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

	var atype: Dictionary = DataLoader.get_attack_type(attack_type_id)
	_attack_mode = str(atype.get("mode", ""))
	_attack_params = atype.get("params", {})
	_crit_mult = DataLoader.get_rule("crit_mult", FALLBACK_CRIT_MULT)
	_cooldown = 0.0

	# 임시 아트. 최종 스프라이트가 나오면 이 두 줄을 지운다.
	modulate = Color.from_string(str(data.get("debug_color", "")), FALLBACK_COLOR)
	scale = Vector2.ONE * float(data.get("debug_scale", 1.0))


## Party 가 투사체 발사에 필요한 것을 넣어 준다.
func set_projectile_source(scene: PackedScene, root: Node2D) -> void:
	_projectile_scene = scene
	_projectiles_root = root


## 라인 슬롯에 세운다. 이후 이 좌표에서 움직이지 않는다.
func place_at(slot_line: String) -> void:
	line = slot_line
	position = BattleLayout.slot_position(slot_line)


func is_alive() -> bool:
	return hp > 0.0


func _process(delta: float) -> void:
	if not is_alive() or _attack_mode.is_empty():
		return

	_cooldown -= delta
	if _cooldown > 0.0:
		return

	var target: Enemy = _find_target()
	if target == null:
		return

	_attack(target)
	_cooldown = 1.0 / maxf(atk_speed, 0.01)


## ---------------------------------------------------------------- 내부

## 사거리 안에서 가장 왼쪽 적. 없으면 null.
func _find_target() -> Enemy:
	var best: Enemy = null
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		if position.distance_to(enemy.position) > atk_range:
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

	attacked.emit(target, packet)


## 치명타는 발사 시점에 한 번만 굴린다. 관통이라도 맞는 적마다 다시 굴리지 않는다.
func _make_packet() -> DamagePacket:
	var is_crit: bool = randf() < crit
	var base: float = atk * (_crit_mult if is_crit else 1.0)
	return DamagePacket.new(base, is_crit, hero_id)


func _fire_projectile(packet: DamagePacket, pierce: int) -> void:
	if _projectile_scene == null or _projectiles_root == null:
		push_error("Unit: 투사체 설정이 없다 — Party 가 set_projectile_source() 를 부르지 않았다.")
		return

	var shot: Projectile = ObjectPool.acquire(_projectile_scene) as Projectile
	if shot == null:
		push_error("Unit: projectile_scene 루트에 projectile.gd 가 없다.")
		return

	shot.modulate = modulate   # 누가 쏜 건지 색으로 구분한다 (임시 아트)
	_projectiles_root.add_child(shot)
	shot.launch(position, packet, float(_attack_params.get("speed", FALLBACK_PROJECTILE_SPEED)), pierce)
