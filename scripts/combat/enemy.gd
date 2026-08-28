class_name Enemy
extends Area2D

## 적. 오른쪽에서 왼쪽으로 직진만 한다.
## 경로탐색 없음. 레인(y) 변경 없음. 방향 전환 없음.
##
## 1주차 범위: 이동과 도달 판정만. 체력/피해는 2주차 DamagePacket에서 붙인다.

## 아이다에게 도달했다.
signal reached_aida(enemy: Enemy)

## 초당 이동 픽셀.
@export var speed: float = 70.0

var _lane: String = "front"
var _advancing: bool = true


## 스포너가 호출한다. 레인과 속도를 정하고 스폰 위치에 놓는다.
func spawn_at(lane: String, move_speed: float) -> void:
	_lane = lane
	speed = move_speed
	position = BattleLayout.spawn_position(lane)
	_advancing = true


func _physics_process(delta: float) -> void:
	if not _advancing:
		return

	position.x -= speed * delta

	if position.x <= BattleLayout.AIDA_HIT_X:
		_advancing = false
		reached_aida.emit(self)


## 전진을 멈춘다. 전열 가신에게 저지당했을 때 사용한다. (2주차)
func stop_advance() -> void:
	_advancing = false


## 전진을 재개한다. 저지하던 가신이 죽었을 때 사용한다. (2주차)
func resume_advance() -> void:
	_advancing = true


func get_lane() -> String:
	return _lane
