extends Node2D

## 전투 씬 루트.
##
## 적 스폰은 ObjectPool 을 거친다. 전투 중 instantiate()/queue_free() 금지.
## 웨이브 스포너는 2주차 다음 항목.

## 인스펙터에서 scenes/entities/enemy.tscn 을 연결한다.
@export var enemy_scene: PackedScene

## 인스펙터에서 Enemies 노드를 연결한다.
@export var enemies_root: Node2D

## 스폰할 적 ID. data/enemies.json 참조.
@export var enemy_id: String = "charger"

## 전투 시작 전 미리 만들어 둘 적 수.
@export var prewarm_count: int = 16

## 레인 안내선을 그린다. 좌표 확인용 임시 표시. 완성 전 끈다.
@export var debug_draw: bool = true

## DataLoader 가 값을 주지 못했을 때만 쓰는 대비값.
const DEFAULT_ENEMY_SPEED: float = 70.0

var _lane_index: int = 0
var _enemy_speed: float = DEFAULT_ENEMY_SPEED


func _ready() -> void:
	if enemy_scene == null:
		push_error("Battle: enemy_scene이 비어 있다. 인스펙터에서 enemy.tscn을 연결할 것.")
		return
	if enemies_root == null:
		push_error("Battle: enemies_root가 비어 있다. 인스펙터에서 Enemies 노드를 연결할 것.")
		return

	_enemy_speed = _load_enemy_speed()
	ObjectPool.prewarm(enemy_scene, prewarm_count)
	_spawn_enemy()


## data/enemies.json 에서 이동 속도를 읽는다. 실패하면 기본값.
func _load_enemy_speed() -> float:
	var row: Dictionary = DataLoader.get_enemy(enemy_id)
	if row.is_empty():
		push_warning("Battle: 적 '%s' 를 찾지 못해 기본 속도를 쓴다." % enemy_id)
		return DEFAULT_ENEMY_SPEED
	return float(row.get("speed", DEFAULT_ENEMY_SPEED))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_spawn_enemy()


## 적 1마리를 다음 레인에 스폰한다. 레인은 front → mid → back 순환.
func _spawn_enemy() -> void:
	if enemy_scene == null or enemies_root == null:
		return

	var lane: String = BattleLayout.LINES[_lane_index]
	_lane_index = (_lane_index + 1) % BattleLayout.LINES.size()

	var enemy: Enemy = ObjectPool.acquire(enemy_scene) as Enemy
	if enemy == null:
		push_error("Battle: enemy_scene의 루트에 enemy.gd가 붙어 있지 않다.")
		return

	# 재사용된 적은 이미 연결돼 있다. 중복 연결하면 시그널이 두 번 온다.
	if not enemy.reached_aida.is_connected(_on_enemy_reached_aida):
		enemy.reached_aida.connect(_on_enemy_reached_aida)

	enemies_root.add_child(enemy)
	enemy.spawn_at(lane, _enemy_speed)


func _on_enemy_reached_aida(enemy: Enemy) -> void:
	print("적이 아이다에 도달 — lane=%s" % enemy.get_lane())
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
