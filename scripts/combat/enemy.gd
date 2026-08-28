class_name Enemy
extends Area2D

## 적. 오른쪽에서 왼쪽으로 직진만 한다.
## 경로탐색 없음. 레인(y) 변경 없음. 방향 전환 없음.
##
## 스탯은 전부 data/enemies.json 에서 온다. 코드에 수치를 적지 않는다.
## 피해는 반드시 DamagePacket 을 거친다. hp 를 직접 깎는 코드를 밖에 두지 않는다.

## 아이다에게 도달했다.
signal reached_aida(enemy: Enemy)

## 체력이 0이 됐다. 스포너가 풀로 돌려보낸다.
signal died(enemy: Enemy)

## setup() 전에 참조될 때만 쓰는 대비값.
const FALLBACK_SPEED: float = 70.0
const FALLBACK_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const FALLBACK_MIN_DAMAGE: float = 1.0
const FALLBACK_ATTACK_INTERVAL: float = 1.0
const FALLBACK_CONTACT_X: float = 40.0

## 가신이 사거리 안의 적을 찾을 때 쓰는 그룹.
const GROUP: StringName = &"enemies"

var enemy_id: String = ""
var display_name: String = ""
var max_hp: float = 0.0
var hp: float = 0.0
var speed: float = FALLBACK_SPEED
var damage: float = 0.0
var defense: float = 0.0
var shard_value: int = 0
var attack_interval: float = FALLBACK_ATTACK_INTERVAL

var _lane: String = "front"
var _lane_pref: String = "any"
var _advancing: bool = false
var _min_damage: float = FALLBACK_MIN_DAMAGE
var _contact_x: float = FALLBACK_CONTACT_X

## 나를 붙잡고 있는 가신. null 이면 전진 중이다.
var _blocked_by: Unit = null
var _attack_timer: float = 0.0


## data/enemies.json 의 항목 하나를 받아 스탯과 외형을 세팅한다.
## DataLoader 가 준 복사본이므로 여기서 값을 바꿔도 원본에 영향이 없다.
func setup(data: Dictionary) -> void:
	if data.is_empty():
		push_error("Enemy.setup: 빈 데이터가 들어왔다.")
		return

	enemy_id = str(data.get("id", ""))
	display_name = str(data.get("name", enemy_id))
	max_hp = float(data.get("hp", 1.0))
	hp = max_hp
	speed = float(data.get("speed", FALLBACK_SPEED))
	damage = float(data.get("damage", 0.0))
	defense = float(data.get("defense", 0.0))
	shard_value = int(data.get("shard_value", 0))
	attack_interval = float(data.get("attack_interval", FALLBACK_ATTACK_INTERVAL))
	_lane_pref = str(data.get("lane_pref", "any"))
	_min_damage = DataLoader.get_rule("min_damage", FALLBACK_MIN_DAMAGE)
	_contact_x = DataLoader.get_rule("block_contact_x", FALLBACK_CONTACT_X)

	# 사거리 탐색 대상이 되려면 그룹에 있어야 한다. 재사용돼도 한 번만 들어간다.
	if not is_in_group(GROUP):
		add_to_group(GROUP)

	# 임시 아트. 최종 스프라이트가 나오면 이 두 줄을 지운다.
	modulate = Color.from_string(str(data.get("debug_color", "")), FALLBACK_COLOR)
	scale = Vector2.ONE * float(data.get("debug_scale", 1.0))


## 레인을 정하고 스폰 위치에 놓는다. setup() 을 먼저 호출해야 한다.
func spawn_at(lane: String) -> void:
	_lane = lane
	position = BattleLayout.spawn_position(lane)
	hp = max_hp
	_advancing = true
	_blocked_by = null
	_attack_timer = 0.0


## 피해를 받는다. 방어력은 맞는 쪽이 알기 때문에 여기서 뺀다.
## packet.base 에는 치명타 배수가 이미 들어 있다.
func take_damage(packet: DamagePacket) -> void:
	if packet == null or not is_alive():
		return

	var dealt: float = maxf(_min_damage, packet.base - defense)
	hp -= dealt

	if hp <= 0.0:
		hp = 0.0
		_advancing = false
		_leave_blocker()
		# 투사체 명중은 물리 콜백 안이다. 거기서 풀에 반납하면 트리에서 못 뗀다.
		died.emit.call_deferred(self)


func is_alive() -> bool:
	return hp > 0.0


func _physics_process(delta: float) -> void:
	# 저지당하는 중이면 멈춰서 붙잡은 가신을 때린다.
	if _blocked_by != null:
		_tick_blocked(delta)
		return

	if not _advancing:
		return

	position.x -= speed * delta

	# 이번 이동으로 가신에게 닿았는지 확인한다. 닿으면 이 프레임은 여기서 끝.
	_try_get_blocked()
	if _blocked_by != null:
		return

	if position.x <= BattleLayout.AIDA_HIT_X:
		_advancing = false
		reached_aida.emit.call_deferred(self)


## ---------------------------------------------------------------- 저지

## 같은 레인의 가신에게 막히는지 본다.
## 저지 수가 찬 가신은 나를 받지 않는다 — 그냥 지나간다. (명일방주의 저지 수)
func _try_get_blocked() -> void:
	for node in get_tree().get_nodes_in_group(Unit.lane_group(_lane)):
		var unit: Unit = node as Unit
		if unit == null or not unit.is_alive():
			continue
		if position.x > unit.position.x + _contact_x:
			continue   # 아직 안 닿았다
		if unit.try_block(self):
			_blocked_by = unit
			_attack_timer = attack_interval
			return


func _tick_blocked(delta: float) -> void:
	if not is_instance_valid(_blocked_by) or not _blocked_by.is_alive():
		on_blocker_lost()
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_blocked_by.take_damage(DamagePacket.new(damage, false, ""))
		_attack_timer = attack_interval


## 붙잡던 가신이 쓰러졌다. 다시 전진한다.
func on_blocker_lost() -> void:
	_blocked_by = null
	_attack_timer = 0.0
	if is_alive():
		_advancing = true


## 저지 목록에서 스스로 빠진다. 죽거나 풀에 반납될 때.
func _leave_blocker() -> void:
	if is_instance_valid(_blocked_by):
		_blocked_by.release_block(self)
	_blocked_by = null


## 저지 중인가.
func is_blocked() -> bool:
	return _blocked_by != null


## 전진을 멈춘다. 전열 가신에게 저지당했을 때 사용한다. (2주차)
func stop_advance() -> void:
	_advancing = false


## 전진을 재개한다. 저지하던 가신이 죽었을 때 사용한다. (2주차)
func resume_advance() -> void:
	_advancing = true


func get_lane() -> String:
	return _lane


## "any" 면 아무 레인이나, 그 외에는 지정된 레인에만 스폰한다.
func get_lane_pref() -> String:
	return _lane_pref


## ObjectPool 이 풀로 되돌릴 때 호출한다. 다음 재사용을 위해 상태를 끈다.
func _on_released() -> void:
	_advancing = false
	_leave_blocker()
