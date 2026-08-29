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
const FALLBACK_DOT_TICK: float = 0.25
const FALLBACK_SPRITE_HEIGHT: float = 110.0

## 저지 중 공격할 때 전투 자세를 보여주는 시간.
const ATTACK_POSE_SEC: float = 0.35

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

## 걸려 있는 지속피해. 각 항목 { dps, remaining }. stack_max 까지만 쌓인다.
var _dots: Array[Dictionary] = []
var _dot_color: Color = Color.WHITE
var _dot_timer: float = 0.0
var _dot_tick: float = FALLBACK_DOT_TICK
var _base_color: Color = FALLBACK_COLOR

var _sprite: Sprite2D = null
var _bar: HealthBar = null
var _tex_idle: Texture2D = null
var _tex_battle: Texture2D = null
var _pose_left: float = 0.0


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
	_dot_tick = DataLoader.get_rule("dot_tick", FALLBACK_DOT_TICK)
	_dots.clear()
	_dot_timer = 0.0

	# 사거리 탐색 대상이 되려면 그룹에 있어야 한다. 재사용돼도 한 번만 들어간다.
	if not is_in_group(GROUP):
		add_to_group(GROUP)

	_apply_art(data)


## 레인을 정하고 스폰 위치에 놓는다. setup() 을 먼저 호출해야 한다.
func spawn_at(lane: String) -> void:
	_lane = lane
	position = BattleLayout.spawn_position(lane)
	hp = max_hp
	_refresh_bar()
	_advancing = true
	_blocked_by = null
	_attack_timer = 0.0


## 피해를 받는다. 방어력은 맞는 쪽이 알기 때문에 여기서 뺀다.
## packet.base 에는 치명타 배수가 이미 들어 있다.
func take_damage(packet: DamagePacket) -> void:
	if packet == null or not is_alive():
		return

	var dealt: float = packet.base if packet.ignore_defense else maxf(_min_damage, packet.base - defense)
	hp -= dealt

	_refresh_bar()

	if not packet.element.is_empty():
		_apply_element(packet)

	if not packet.silent_number:
		var hit_at: Vector2 = position + Vector2(0.0, -_hit_offset_y())
		Effects.damage(hit_at, dealt, Effects.COLOR_ENEMY_HIT, packet.is_crit)
		Effects.hit(hit_at, _element_color(packet))

	if hp <= 0.0:
		hp = 0.0
		_advancing = false
		Effects.kill(position + Vector2(0.0, -_hit_offset_y()), _dot_color if not _dots.is_empty() else Effects.COLOR_ENEMY_HIT)
		_leave_blocker()
		# 투사체 명중은 물리 콜백 안이다. 거기서 풀에 반납하면 트리에서 못 뗀다.
		died.emit.call_deferred(self)


func is_alive() -> bool:
	return hp > 0.0


func _physics_process(delta: float) -> void:
	_tick_dots(delta)
	_tick_pose(delta)
	if not is_alive():
		return

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


## 스프라이트가 있으면 그걸 쓰고, 없으면 임시 색 사각형으로 돌아간다.
## 발끝이 레인 y 에 닿도록 offset 을 내린다.
func _apply_art(data: Dictionary) -> void:
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	_bar = get_node_or_null("HealthBar") as HealthBar
	if _bar != null:
		_bar.visible = true
	_tex_idle = _load_tex(str(data.get("sprite_idle", "")))
	_tex_battle = _load_tex(str(data.get("sprite_battle", "")))
	_pose_left = 0.0

	if _sprite == null or _tex_idle == null:
		_base_color = Color.from_string(str(data.get("debug_color", "")), FALLBACK_COLOR)
		modulate = _base_color
		scale = Vector2.ONE * float(data.get("debug_scale", 1.0))
		_setup_bar(48.0, 60.0)
		return

	# 스프라이트를 쓰면 기본색은 흰색이다. 불에 타면 여기서 주황으로 물든다.
	_base_color = Color.WHITE
	modulate = _base_color
	scale = Vector2.ONE
	_sprite.texture = _tex_idle
	var h: float = float(data.get("sprite_height", FALLBACK_SPRITE_HEIGHT))
	var k: float = h / float(_tex_idle.get_height())
	_sprite.scale = Vector2(k, k)
	_sprite.offset = Vector2(0.0, -float(_tex_idle.get_height()) * 0.5)
	_setup_bar(float(_tex_idle.get_width()) * k, h)


func _load_tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 체력바를 스프라이트 폭에 맞추고 머리 위로 올린다.
func _setup_bar(sprite_width: float, sprite_height: float) -> void:
	if _bar == null:
		return
	_bar.setup(clampf(sprite_width * 0.9, 30.0, 140.0), -(sprite_height + 10.0))
	_refresh_bar()


func _refresh_bar() -> void:
	if _bar != null and max_hp > 0.0:
		_bar.set_ratio(hp / max_hp)


func _show_attack_pose() -> void:
	if _sprite == null or _tex_battle == null:
		return
	_sprite.texture = _tex_battle
	_pose_left = ATTACK_POSE_SEC


func _tick_pose(delta: float) -> void:
	if _pose_left <= 0.0:
		return
	_pose_left -= delta
	if _pose_left <= 0.0 and _sprite != null and _tex_idle != null:
		_sprite.texture = _tex_idle


## ---------------------------------------------------------------- 속성

## 맞은 속성의 효과를 건다. 수치는 packet.element_params 에 실려 온다.
## 화염 외 속성은 3주차 범위 밖이라 조용히 무시한다.
func _apply_element(packet: DamagePacket) -> void:
	var params: Dictionary = packet.element_params
	if str(params.get("type", "")) != "dot":
		return

	var stack_max: int = maxi(1, int(params.get("stack_max", 1)))
	var duration: float = float(params.get("duration", 0.0))
	var dps: float = float(params.get("dps", 0.0))
	if duration <= 0.0 or dps <= 0.0:
		return

	_dot_color = Color.from_string(str(params.get("vfx_color", "")), Color(1.0, 0.5, 0.2))

	if _dots.size() >= stack_max:
		# 꽉 찼으면 가장 먼저 꺼질 스택의 시간을 새로 고친다.
		var soonest: int = 0
		for i in _dots.size():
			if float(_dots[i]["remaining"]) < float(_dots[soonest]["remaining"]):
				soonest = i
		_dots[soonest]["remaining"] = duration
		_dots[soonest]["dps"] = dps
		return

	_dots.append({ "dps": dps, "remaining": duration })


## 지속피해를 일정 간격으로 넣는다. 매 프레임 넣으면 피해 묶음만 낭비된다.
## 방어력을 무시한다 — 틱당 피해가 작아서 방어력을 빼면 최소피해로 떨어진다.
func _tick_dots(delta: float) -> void:
	if _dots.is_empty():
		return

	var dps_sum: float = 0.0
	for i in range(_dots.size() - 1, -1, -1):
		_dots[i]["remaining"] = float(_dots[i]["remaining"]) - delta
		if float(_dots[i]["remaining"]) <= 0.0:
			_dots.remove_at(i)
		else:
			dps_sum += float(_dots[i]["dps"])

	_update_burn_tint()

	if dps_sum <= 0.0:
		return

	_dot_timer -= delta
	if _dot_timer > 0.0:
		return
	_dot_timer = _dot_tick

	var packet := DamagePacket.new(dps_sum * _dot_tick, false, "")
	packet.ignore_defense = true
	packet.silent_number = true   # 0.25초마다 숫자가 뜨면 화면이 가려진다
	take_damage(packet)


## 스택이 많을수록 더 타오른다. 깜빡여서 "지금 불붙어 있다" 를 알린다.
func _update_burn_tint() -> void:
	if _dots.is_empty():
		modulate = _base_color
		return
	var weight: float = clampf(0.35 + 0.2 * _dots.size(), 0.0, 0.9)
	var pulse: float = 0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.012)
	modulate = _base_color.lerp(_dot_color, weight) * pulse
	modulate.a = 1.0


## 피격 이펙트가 뜰 높이. 발끝이 아니라 몸통 가운데쯤에서 터져야 자연스럽다.
func _hit_offset_y() -> float:
	if _sprite != null and _sprite.texture != null:
		return _sprite.texture.get_height() * _sprite.scale.y * 0.55
	return 30.0


## 맞은 속성의 색. 무속성이면 기본색.
func _element_color(packet: DamagePacket) -> Color:
	var hex: String = str(packet.element_params.get("vfx_color", ""))
	if packet.element.is_empty() or hex.is_empty():
		return Effects.COLOR_ENEMY_HIT
	return Color.from_string(hex, Effects.COLOR_ENEMY_HIT)


## 지금 불타는 중인가. 연출·디버그용.
func get_dot_stacks() -> int:
	return _dots.size()


## ---------------------------------------------------------------- 저지

## 같은 레인의 가신에게 막히는지 본다.
## 저지 수가 찬 가신은 나를 받지 않는다 — 그냥 지나간다. (명일방주의 저지 수)
func _try_get_blocked() -> void:
	# 같은 레인에서 **가장 오른쪽** 가신부터 만난다. 열1이 먼저, 뚫리면 열2가 받는다.
	var best: Unit = null
	for node in get_tree().get_nodes_in_group(Unit.lane_group(_lane)):
		var unit: Unit = node as Unit
		if unit == null or not unit.is_alive():
			continue
		if position.x > unit.position.x + _contact_x:
			continue   # 아직 안 닿았다
		if best == null or unit.position.x > best.position.x:
			best = unit

	if best != null and best.try_block(self):
		_blocked_by = best
		_attack_timer = attack_interval


func _tick_blocked(delta: float) -> void:
	if not is_instance_valid(_blocked_by) or not _blocked_by.is_alive():
		on_blocker_lost()
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_show_attack_pose()
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
	_dots.clear()
	modulate = _base_color
