class_name UnitVisual
extends RefCounted

## 가신의 겉모습. 스프라이트 두 장 교체와 머리 위 체력바.
##
## unit.gd 가 500줄을 넘어서 떼어냈다 (CLAUDE.md 금지 항목).
## 전투 규칙과 무관한 표시 전용이라 분리해도 손해가 없다.

## 공격 자세를 보여주는 시간. 프레임 애니메이션이 아니라 두 장 교체다.
const ATTACK_POSE_SEC: float = 0.35

const FALLBACK_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)

var _node: Node2D = null
var _sprite: Sprite2D = null
var _bar: HealthBar = null
var _idle: Texture2D = null
var _battle: Texture2D = null
var _pose_left: float = 0.0


## 스프라이트가 있으면 그걸 쓰고, 없으면 임시 색 사각형으로 돌아간다.
## 발끝이 타일 좌표에 닿도록 offset 을 내린다 — 서 있는 바닥이 곧 노드 위치다.
func setup(node: Node2D, data: Dictionary, height: float) -> void:
	_node = node
	_sprite = node.get_node_or_null("Sprite2D") as Sprite2D
	_bar = node.get_node_or_null("HealthBar") as HealthBar
	_idle = _load_tex(str(data.get("sprite_idle", "")))
	_battle = _load_tex(str(data.get("sprite_battle", "")))
	_pose_left = 0.0

	if _sprite == null or _idle == null:
		node.modulate = Color.from_string(str(data.get("debug_color", "")), FALLBACK_COLOR)
		node.scale = Vector2.ONE * float(data.get("debug_scale", 1.0))
		_setup_bar(48.0, 60.0)
		return

	node.modulate = Color.WHITE
	node.scale = Vector2.ONE
	_sprite.texture = _idle
	var k: float = height / float(_idle.get_height())
	_sprite.scale = Vector2(k, k)
	_sprite.offset = Vector2(0.0, -float(_idle.get_height()) * 0.5)
	_setup_bar(float(_idle.get_width()) * k, height)


## 공격 순간 잠깐 전투 자세로 바꾼다.
func show_attack() -> void:
	if _sprite == null or _battle == null:
		return
	_sprite.texture = _battle
	_pose_left = ATTACK_POSE_SEC


func tick(delta: float) -> void:
	if _pose_left <= 0.0:
		return
	_pose_left -= delta
	if _pose_left <= 0.0 and _sprite != null and _idle != null:
		_sprite.texture = _idle


func set_hp_ratio(ratio: float) -> void:
	if _bar != null:
		_bar.set_ratio(ratio)


## 쓰러진 표시. 어둡게 하고 체력바를 숨긴다.
func mark_dead() -> void:
	if _node != null:
		_node.modulate = Color(0.35, 0.35, 0.35, 0.6)
	if _bar != null:
		_bar.visible = false


func _setup_bar(sprite_width: float, sprite_height: float) -> void:
	if _bar == null:
		return
	_bar.setup(clampf(sprite_width * 0.9, 34.0, 120.0), -(sprite_height + 12.0))


func _load_tex(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
