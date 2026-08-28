class_name Projectile
extends Area2D

## 가신이 쏜 투사체. 왼쪽(가신)에서 오른쪽(적)으로만 날아간다.
## 유도 없음. 중력 없음. 직선뿐이다.
##
## 관통(pierce)은 같은 적을 두 번 때리지 않도록 맞힌 적을 기억한다.
## 풀에서 재사용되므로 setup() 에서 상태를 전부 초기화한다.

## 수명이 끝났다. 반납은 투사체가 스스로 한다. 이 신호는 연출·집계용이다.
##
## 반납을 쏜 가신에게 맡기면 안 된다. 같은 투사체가 풀을 돌며 여러 가신에게 재사용되고,
## 그때마다 핸들러가 하나씩 더 붙어서 한 번 만료에 여러 번 반납된다.
signal expired(projectile: Projectile)

## 이 x 를 넘어가면 화면 밖이다.
const DESPAWN_X: float = 1500.0

var speed: float = 600.0
var max_pierce: int = 1

var _packet: DamagePacket = null
var _pierced: int = 0
var _hit_ids: Array[int] = []
var _active: bool = false
var _expiring: bool = false


func _ready() -> void:
	# 풀에서 재사용되어도 연결은 한 번만 한다.
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


## 발사. 맞은 적에게 넘길 피해는 미리 만들어 둔 packet 을 그대로 쓴다.
## 관통이라도 같은 발사에서 나온 피해는 동일하다.
func launch(from: Vector2, packet: DamagePacket, move_speed: float, pierce: int) -> void:
	position = from
	_packet = packet
	speed = move_speed
	max_pierce = maxi(1, pierce)
	_pierced = 0
	_hit_ids.clear()
	_active = true
	_expiring = false


func _physics_process(delta: float) -> void:
	if not _active:
		return

	position.x += speed * delta
	if position.x >= DESPAWN_X:
		_expire()


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return

	var enemy: Enemy = area as Enemy
	if enemy == null or not enemy.is_alive():
		return

	# 관통 중 같은 적을 다시 통과할 수 있다. 한 번만 때린다.
	var id: int = enemy.get_instance_id()
	if id in _hit_ids:
		return
	_hit_ids.append(id)

	enemy.take_damage(_packet)

	_pierced += 1
	if _pierced >= max_pierce:
		_expire()


## area_entered 는 물리 콜백 안이다. 거기서 노드를 트리에서 떼면 Godot 이 거부한다.
## 그래서 만료 통보를 다음 프레임으로 미룬다. _active 는 즉시 꺼서 추가 명중을 막는다.
func _expire() -> void:
	_active = false
	if _expiring:
		return
	_expiring = true
	_finish.call_deferred()


func _finish() -> void:
	expired.emit(self)
	ObjectPool.release(self)


## ObjectPool 이 풀로 되돌릴 때 호출한다.
func _on_released() -> void:
	_active = false
	_expiring = false
	_packet = null
	_hit_ids.clear()
