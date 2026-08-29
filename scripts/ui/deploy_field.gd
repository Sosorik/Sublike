class_name DeployField
extends Node2D

## 배치 타일 9칸. 격자를 그리고 클릭을 받는다.
##
## 손패에서 가신을 고르면 놓을 수 있는 타일이 밝아지고, 못 놓는 타일은 어두워진다.
## 아무것도 고르지 않은 상태에서 배치된 가신을 누르면 철수 대상으로 선택된다.

## 빈 타일을 눌렀다. (레인, 열)
signal tile_selected(lane: String, column: int)
## 배치된 가신을 눌렀다. 철수 후보다.
signal unit_selected(unit: Unit)
## 빈 곳을 눌러 선택이 풀렸다.
signal selection_cleared()

## 타일 하나의 크기. 클릭 판정도 이 크기로 한다.
const TILE_SIZE: Vector2 = Vector2(132.0, 104.0)

const LANE_LINE: Color = Color(1.0, 1.0, 1.0, 0.08)
const GROUND_FILL: Color = Color(0.40, 0.62, 0.95, 0.16)
const HIGH_FILL: Color = Color(0.95, 0.78, 0.42, 0.16)
const EDGE: Color = Color(1.0, 1.0, 1.0, 0.22)
const OK_FILL: Color = Color(0.45, 0.95, 0.55, 0.30)
const OK_EDGE: Color = Color(0.6, 1.0, 0.7, 0.95)
const NO_FILL: Color = Color(0.1, 0.1, 0.12, 0.45)
const BLOCKED_FILL: Color = Color(0.02, 0.02, 0.03, 0.55)
const PICK_EDGE: Color = Color(1.0, 0.85, 0.35, 0.95)

## 인스펙터에서 Party 를 연결한다.
@export var party: Node

## 격자를 그린다. 정식 타일 아트가 나오면 끈다.
@export var draw_grid: bool = true

var _selected_hero: String = ""
var _selected_unit: Unit = null


## 손패에서 고른 가신. 빈 문자열이면 선택 해제.
func set_selected_hero(hero_id: String) -> void:
	_selected_hero = hero_id
	_selected_unit = null
	queue_redraw()


func get_selected_hero() -> String:
	return _selected_hero


func get_selected_unit() -> Unit:
	return _selected_unit


func clear_selection() -> void:
	_selected_hero = ""
	_selected_unit = null
	queue_redraw()
	selection_cleared.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return

	if mb.button_index == MOUSE_BUTTON_RIGHT:
		clear_selection()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var tile: Vector2i = tile_at(get_global_mouse_position())
	if tile.x < 0:
		clear_selection()
		return

	var lane: String = BattleLayout.LANES[tile.x]
	var occupant: Unit = party.get_unit_at(lane, tile.y) if party != null else null

	if not _selected_hero.is_empty():
		# 배치 시도. 성공 여부는 Party 가 판단한다.
		tile_selected.emit(lane, tile.y)
		return

	if occupant != null:
		_selected_unit = occupant
		queue_redraw()
		unit_selected.emit(occupant)
	else:
		clear_selection()


## 좌표가 어느 타일인가. (레인 인덱스, 열 인덱스). 없으면 (-1, -1).
func tile_at(world_pos: Vector2) -> Vector2i:
	var half: Vector2 = TILE_SIZE * 0.5
	for li in BattleLayout.lane_count():
		for ci in BattleLayout.column_count():
			var c: Vector2 = BattleLayout.tile_position(li, ci)
			if Rect2(c - half, TILE_SIZE).has_point(world_pos):
				return Vector2i(li, ci)
	return Vector2i(-1, -1)


func _draw() -> void:
	if not draw_grid:
		return

	for lane in BattleLayout.LANES:
		var y: float = BattleLayout.lane_y(lane)
		draw_line(Vector2(0.0, y), Vector2(1280.0, y), LANE_LINE, 2.0)

	var half: Vector2 = TILE_SIZE * 0.5
	var picking: bool = not _selected_hero.is_empty()

	for li in BattleLayout.lane_count():
		for ci in BattleLayout.column_count():
			var lane: String = BattleLayout.LANES[li]
			var rect := Rect2(BattleLayout.tile_position(li, ci) - half, TILE_SIZE)
			var kind: String = party.tile_kind(li, ci) if party != null else BattleLayout.GROUND

			# 막힌 타일은 아예 안 그린다. 층마다 지형이 다르다.
			if kind == BattleLayout.BLOCKED:
				draw_rect(rect, BLOCKED_FILL)
				continue

			var is_ground: bool = kind == BattleLayout.GROUND

			if picking:
				# 놓을 수 있는 칸만 밝게. 나머지는 덮어서 눈에서 지운다.
				var ok: bool = party != null and party.can_deploy(_selected_hero, lane, ci)
				draw_rect(rect, OK_FILL if ok else NO_FILL)
				draw_rect(rect, OK_EDGE if ok else EDGE, false, 3.0 if ok else 1.0)
			else:
				draw_rect(rect, GROUND_FILL if is_ground else HIGH_FILL)
				draw_rect(rect, EDGE, false, 2.0)

	# 철수 후보 표시
	if is_instance_valid(_selected_unit):
		var li2: int = BattleLayout.lane_index_of(_selected_unit.lane)
		if li2 >= 0:
			var r := Rect2(BattleLayout.tile_position(li2, _selected_unit.column) - half, TILE_SIZE)
			draw_rect(r, PICK_EDGE, false, 4.0)
