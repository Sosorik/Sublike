class_name HitEffect
extends Node2D

## 피격 / 처치 순간의 파티클 한 방. 아트 리소스 없이 화면을 채우는 수단이다.
## (CLAUDE.md "화려함은 이펙트가 만든다")

signal expired(node: HitEffect)

## 파티클이 다 사라질 때까지 기다리는 시간.
const LINGER: float = 0.55

## 인스펙터에서 CPUParticles2D 를 연결한다.
@export var particles: CPUParticles2D

var _left: float = 0.0


## 터뜨린다. scale_mult 를 키우면 더 크게 터진다 (처치 연출용).
func burst(at: Vector2, color: Color, scale_mult: float = 1.0, count: int = 10) -> void:
	if particles == null:
		return
	position = at
	particles.color = color
	particles.amount = maxi(1, count)
	particles.initial_velocity_min = 90.0 * scale_mult
	particles.initial_velocity_max = 240.0 * scale_mult
	particles.scale_amount_min = 2.0 * scale_mult
	particles.scale_amount_max = 4.5 * scale_mult
	particles.restart()
	particles.emitting = true
	_left = LINGER


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		expired.emit(self)


func _on_released() -> void:
	_left = 0.0
	if particles != null:
		particles.emitting = false
