class_name HealthBar
extends Node2D

## 유닛 머리 위 체력바. 스프라이트보다 뒤에 그려지면 안 되므로
## 부모가 아니라 **자식 노드**로 두고 여기서 직접 그린다.
##
## 텍스처를 쓰지 않는다 — 사각형 두 개면 충분하고, 아트 리소스를 늘리지 않는다.

const BORDER: Color = Color(0.05, 0.05, 0.07, 0.85)
const BACK: Color = Color(0.16, 0.16, 0.2, 0.9)

## 가득 찼을 때 숨긴다. 적처럼 수가 많은 쪽에 쓴다.
@export var hide_when_full: bool = true

## 아군 색 계열을 쓸지. false 면 적 색.
@export var ally: bool = false

var _width: float = 44.0
var _height: float = 5.0
var _ratio: float = 1.0


## 크기와 높이를 정한다. 유닛마다 스프라이트 크기가 달라서 배치할 때 넣어 준다.
func setup(width: float, y_offset: float, bar_height: float = 5.0) -> void:
	_width = maxf(12.0, width)
	_height = maxf(3.0, bar_height)
	position = Vector2(0.0, y_offset)
	queue_redraw()


## 0~1. 값이 바뀔 때만 다시 그린다.
func set_ratio(ratio: float) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	if is_equal_approx(r, _ratio):
		return
	_ratio = r
	queue_redraw()


func _draw() -> void:
	if hide_when_full and _ratio >= 1.0:
		return

	var origin := Vector2(-_width * 0.5, -_height * 0.5)
	draw_rect(Rect2(origin - Vector2(1.0, 1.0), Vector2(_width + 2.0, _height + 2.0)), BORDER)
	draw_rect(Rect2(origin, Vector2(_width, _height)), BACK)
	if _ratio > 0.0:
		draw_rect(Rect2(origin, Vector2(_width * _ratio, _height)), _fill_color())


## 남은 비율에 따라 색이 변한다. 위험한 상태가 눈에 띄어야 한다.
func _fill_color() -> Color:
	if ally:
		if _ratio > 0.5:
			return Color(0.35, 0.85, 0.4)
		return Color(0.95, 0.75, 0.25) if _ratio > 0.25 else Color(0.95, 0.3, 0.28)
	if _ratio > 0.5:
		return Color(0.88, 0.35, 0.32)
	return Color(0.95, 0.55, 0.25) if _ratio > 0.25 else Color(1.0, 0.85, 0.4)
