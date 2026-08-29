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
var element: String = ""          ## "" = 무속성. 부여된 속성 ID ("fire" 등)
var source_hero_id: String = ""

## 속성 세부 수치. aida_skills.json 의 effect 블록이 그대로 온다.
## element 가 비어 있으면 의미 없다. 맞는 쪽이 읽어서 처리한다.
var element_params: Dictionary = {}

## 피해 숫자를 띄우지 않는다. 지속피해가 0.25초마다 숫자를 뿌리면 화면이 가려진다.
var silent_number: bool = false

## 방어력을 무시한다. 지속피해와 신성 속성이 쓴다.
## 지속피해에 방어력을 빼면 틱마다 최소피해로 떨어져 오히려 더 아파진다.
var ignore_defense: bool = false


func _init(p_base: float = 0.0, p_is_crit: bool = false, p_source: String = "") -> void:
	base = p_base
	is_crit = p_is_crit
	source_hero_id = p_source


func _to_string() -> String:
	return "DamagePacket(%.1f%s%s from %s)" % [
		base,
		" CRIT" if is_crit else "",
		" " + element if not element.is_empty() else "",
		source_hero_id,
	]
