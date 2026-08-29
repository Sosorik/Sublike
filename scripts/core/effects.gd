extends Node

## 전투 연출 창구. autoload 이름: Effects
##
## 피해 숫자와 피격 파티클은 매 프레임 수십 개가 생긴다. 전부 풀을 거친다.
## (docs/ARCHITECTURE.md "오브젝트 풀" — DamageNumber, HitEffect 는 필수 대상)
##
## 전투 씬이 set_root() 로 자기 컨테이너를 넘겨 준다.
## 넘겨받기 전에는 조용히 아무것도 하지 않는다 — 로비에서 호출돼도 터지지 않게.

const NUMBER_SCENE: String = "res://scenes/effects/damage_number.tscn"
const HIT_SCENE: String = "res://scenes/effects/hit_effect.tscn"

const COLOR_ENEMY_HIT: Color = Color(1.0, 0.95, 0.85)   ## 적이 맞았다
const COLOR_ALLY_HIT: Color = Color(1.0, 0.55, 0.5)     ## 가신·아이다가 맞았다
const COLOR_CRIT: Color = Color(1.0, 0.85, 0.3)         ## 치명타

var _root: Node2D = null
var _number_scene: PackedScene = null
var _hit_scene: PackedScene = null


func _ready() -> void:
	_number_scene = load(NUMBER_SCENE) as PackedScene
	_hit_scene = load(HIT_SCENE) as PackedScene


## 전투 씬이 자기 이펙트 컨테이너를 넘긴다. 미리 만들어 두기도 한다.
func set_root(root: Node2D, prewarm_numbers: int = 32, prewarm_hits: int = 24) -> void:
	_root = root
	if _root == null:
		return
	if _number_scene != null:
		ObjectPool.prewarm(_number_scene, prewarm_numbers)
	if _hit_scene != null:
		ObjectPool.prewarm(_hit_scene, prewarm_hits)


## 피해 숫자를 띄운다.
func damage(at: Vector2, amount: float, color: Color = COLOR_ENEMY_HIT, is_crit: bool = false) -> void:
	if _root == null or _number_scene == null:
		return
	var n: DamageNumber = ObjectPool.acquire(_number_scene) as DamageNumber
	if n == null:
		return
	if not n.expired.is_connected(_on_number_expired):
		n.expired.connect(_on_number_expired)
	_root.add_child(n)
	n.show_value(at, amount, COLOR_CRIT if is_crit else color, is_crit)


## 피격 파티클.
func hit(at: Vector2, color: Color = COLOR_ENEMY_HIT) -> void:
	_burst(at, color, 1.0, 10)


## 처치 파티클. 더 크게 터진다.
func kill(at: Vector2, color: Color = COLOR_ENEMY_HIT) -> void:
	_burst(at, color, 1.9, 22)


func _burst(at: Vector2, color: Color, scale_mult: float, count: int) -> void:
	if _root == null or _hit_scene == null:
		return
	var e: HitEffect = ObjectPool.acquire(_hit_scene) as HitEffect
	if e == null:
		return
	if not e.expired.is_connected(_on_hit_expired):
		e.expired.connect(_on_hit_expired)
	_root.add_child(e)
	e.burst(at, color, scale_mult, count)


func _on_number_expired(n: DamageNumber) -> void:
	ObjectPool.release(n)


func _on_hit_expired(e: HitEffect) -> void:
	ObjectPool.release(e)
