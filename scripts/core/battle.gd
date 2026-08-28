extends Node2D

## 전투 씬 루트.
##
## 적 스폰은 ObjectPool 을 거친다. 전투 중 instantiate()/queue_free() 금지.
## 웨이브 스포너는 2주차 다음 항목.

## 인스펙터에서 scenes/entities/enemy.tscn 을 연결한다.
@export var enemy_scene: PackedScene

## 인스펙터에서 Enemies 노드를 연결한다.
@export var enemies_root: Node2D

## 전투 시작 전 미리 만들어 둘 적 수.
@export var prewarm_count: int = 16

## 레인 안내선을 그린다. 좌표 확인용 임시 표시. 완성 전 끈다.
@export var debug_draw: bool = true

## data/enemies.json 의 적 3종. JSON 순서대로 돌아가며 스폰한다.
var _enemy_rows: Array[Dictionary] = []

var _lane_index: int = 0
var _type_index: int = 0


func _ready() -> void:
	if enemy_scene == null:
		push_error("Battle: enemy_scene이 비어 있다. 인스펙터에서 enemy.tscn을 연결할 것.")
		return
	if enemies_root == null:
		push_error("Battle: enemies_root가 비어 있다. 인스펙터에서 Enemies 노드를 연결할 것.")
		return

	_enemy_rows = DataLoader.get_all(DataLoader.GROUP_ENEMIES)
	if _enemy_rows.is_empty():
		push_error("Battle: data/enemies.json 에서 적을 하나도 읽지 못했다.")
		return

	ObjectPool.prewarm(enemy_scene, prewarm_count)
	_spawn_enemy()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_spawn_enemy()


## 적 1마리를 스폰한다. 적 종류는 JSON 순서대로, 레인은 front → mid → back 순환.
## lane_pref 가 "any" 가 아닌 적은 지정된 레인에만 나온다. (중갑체는 전열 고정)
func _spawn_enemy() -> void:
	if enemy_scene == null or enemies_root == null or _enemy_rows.is_empty():
		return

	var row: Dictionary = _enemy_rows[_type_index]
	_type_index = (_type_index + 1) % _enemy_rows.size()

	var enemy: Enemy = ObjectPool.acquire(enemy_scene) as Enemy
	if enemy == null:
		push_error("Battle: enemy_scene의 루트에 enemy.gd가 붙어 있지 않다.")
		return

	# 재사용된 적은 이미 연결돼 있다. 중복 연결하면 시그널이 두 번 온다.
	if not enemy.reached_aida.is_connected(_on_enemy_reached_aida):
		enemy.reached_aida.connect(_on_enemy_reached_aida)

	enemy.setup(row)
	enemies_root.add_child(enemy)
	enemy.spawn_at(_pick_lane(enemy.get_lane_pref()))

	print("스폰 — %s(%s) lane=%s speed=%.0f hp=%.0f" % [
		enemy.display_name, enemy.enemy_id, enemy.get_lane(), enemy.speed, enemy.max_hp
	])


## lane_pref 를 실제 레인으로 바꾼다. "any" 면 순환, 아니면 지정 레인.
func _pick_lane(lane_pref: String) -> String:
	if lane_pref != "any":
		if lane_pref in BattleLayout.LINES:
			return lane_pref
		push_warning("Battle: 알 수 없는 lane_pref '%s' — 순환 레인을 쓴다." % lane_pref)

	var lane: String = BattleLayout.LINES[_lane_index]
	_lane_index = (_lane_index + 1) % BattleLayout.LINES.size()
	return lane


func _on_enemy_reached_aida(enemy: Enemy) -> void:
	print("도달 — %s lane=%s (아이다 피해 %.0f)" % [
		enemy.display_name, enemy.get_lane(), enemy.damage
	])
	# 아이다 HP 감소는 2주차 마지막 항목에서 붙인다.
	ObjectPool.release(enemy)


## 레인 안내선. 좌표가 문서와 맞는지 눈으로 확인하기 위한 임시 표시.
func _draw() -> void:
	if not debug_draw:
		return

	var lane_color := Color(1.0, 1.0, 1.0, 0.12)
	var slot_color := Color(0.4, 0.8, 1.0, 0.9)
	var hit_color := Color(1.0, 0.3, 0.3, 0.5)

	for line in BattleLayout.LINES:
		var y: float = BattleLayout.lane_y(line)
		draw_line(Vector2(0.0, y), Vector2(1280.0, y), lane_color, 2.0)
		draw_circle(BattleLayout.slot_position(line), 12.0, slot_color)

	# 아이다 피해선
	draw_line(
		Vector2(BattleLayout.AIDA_HIT_X, 0.0),
		Vector2(BattleLayout.AIDA_HIT_X, 720.0),
		hit_color,
		3.0
	)
	# 아이다 위치
	draw_circle(Vector2(BattleLayout.AIDA_X, BattleLayout.AIDA_Y), 16.0, Color(0.6, 1.0, 0.6, 0.9))
