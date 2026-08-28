extends Node2D

## 전투 씬 루트.
##
## 스폰은 EnemySpawner 가 전담한다. 여기서는 진행 상황 로그와 레인 안내선만 담당한다.
## 아이다 HP / 실패 처리는 2주차 마지막 항목.

## 인스펙터에서 EnemySpawner 노드를 연결한다.
@export var spawner: Node

## 레인 안내선을 그린다. 좌표 확인용 임시 표시. 완성 전 끈다.
@export var debug_draw: bool = true


func _ready() -> void:
	if spawner == null:
		push_error("Battle: spawner 가 비어 있다. 인스펙터에서 EnemySpawner 를 연결할 것.")
		return

	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.floor_cleared.connect(_on_floor_cleared)


func _on_wave_started(wave_number: int, total_waves: int, enemy_count: int) -> void:
	print("웨이브 %d/%d 시작 — 적 %d마리" % [wave_number, total_waves, enemy_count])


func _on_wave_cleared(wave_number: int) -> void:
	print("웨이브 %d 클리어" % wave_number)


func _on_floor_cleared() -> void:
	print("층 클리어 — 강화 3택은 4주차 항목")


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
