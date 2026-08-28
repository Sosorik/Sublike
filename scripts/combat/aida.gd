class_name Aida
extends Node2D

## 아이다. 좌측 고정. 이동하지 않는다.
## 적이 아이다 피해선(BattleLayout.AIDA_HIT_X)을 넘으면 여기 체력이 깎인다.
## 체력이 0이 되면 그 판은 실패다.
##
## 피해는 반드시 DamagePacket 을 거친다. 적이 준 피해도 예외가 아니다.
## 이때 packet.source_hero_id 는 비어 있다 — 가신이 준 피해가 아니라는 뜻이다.

## 체력이 바뀌었다. (현재값, 최대값)
signal hp_changed(hp: float, max_hp: float)

## 체력이 0이 됐다. 판 실패.
signal died()

const FALLBACK_MAX_HP: float = 100.0

var max_hp: float = FALLBACK_MAX_HP
var hp: float = FALLBACK_MAX_HP

var _dead: bool = false


func _ready() -> void:
	position = Vector2(BattleLayout.AIDA_X, BattleLayout.AIDA_Y)
	max_hp = DataLoader.get_rule("aida_max_hp", FALLBACK_MAX_HP)
	hp = max_hp
	# 자식의 _ready() 가 부모보다 먼저 돈다. 부모가 연결할 틈을 준다.
	_announce.call_deferred()


func take_damage(packet: DamagePacket) -> void:
	if packet == null or _dead:
		return

	# 아이다는 방어력이 없다. 들어온 피해를 그대로 받는다.
	hp = maxf(0.0, hp - packet.base)
	hp_changed.emit(hp, max_hp)

	if hp <= 0.0:
		_dead = true
		died.emit()


## 회복. 최대치를 넘지 않는다.
func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)


func is_alive() -> bool:
	return not _dead


func get_hp_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return hp / max_hp


func _announce() -> void:
	hp_changed.emit(hp, max_hp)
