class_name DamagePacket
extends RefCounted

## 피해 한 건. 모든 피해는 반드시 이걸 거친다.
## 어디에서도 `hp -= damage` 를 직접 쓰지 않는다. (docs/ARCHITECTURE.md "전투 파이프라인")
##
## base 는 치명타 배수까지 이미 곱해진 값이다. is_crit 은 연출·UI 용 표시다.
## 방어력은 맞는 쪽이 안다. 그래서 Enemy.take_damage() 에서 뺀다.
##
## 아이다 버프 / 속성 부여 / 런 내 강화는 3~4주차에 이 사이에 끼어든다.
## 그때 apply_* 단계가 여기 추가된다.

var base: float = 0.0
var is_crit: bool = false
var element: String = ""          ## "" = 무속성. 화염/빙결 등은 3주차
var source_hero_id: String = ""


func _init(p_base: float = 0.0, p_is_crit: bool = false, p_source: String = "") -> void:
	base = p_base
	is_crit = p_is_crit
	source_hero_id = p_source


func _to_string() -> String:
	return "DamagePacket(%.1f%s from %s)" % [base, " CRIT" if is_crit else "", source_hero_id]
