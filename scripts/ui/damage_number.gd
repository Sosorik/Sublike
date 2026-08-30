class_name DamageNumber
extends Node2D

## 뜬 피해 숫자. 위로 떠오르며 사라진다.
## 풀에서 재사용되므로 show_value() 에서 상태를 전부 초기화한다.

## 수명이 끝났다. 반납은 스스로 한다.
signal expired(node: DamageNumber)

const RISE: float = 46.0
const LIFE: float = 0.62
const SPREAD: float = 14.0

## 인스펙터에서 Label 을 연결한다.
@export var label: Label

var _finishing: bool = false


## 숫자를 띄운다. big 이면 치명타라 더 크게 뜬다.
func show_value(at: Vector2, amount: float, color: Color, big: bool) -> void:
	show_text(at, str(maxi(1, roundi(amount))), color, big)


## 아무 글자나 띄운다. 스킬 이름 표시에 쓴다.
func show_text(at: Vector2, text: String, color: Color, big: bool) -> void:
	if label == null:
		return
	position = at + Vector2(randf_range(-SPREAD, SPREAD), randf_range(-6.0, 6.0))
	label.text = text
	label.modulate = color
	scale = Vector2.ONE * (1.45 if big else 1.0)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	_finishing = false

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE, LIFE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish)


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	expired.emit(self)


func _on_released() -> void:
	_finishing = false
	modulate.a = 0.0
