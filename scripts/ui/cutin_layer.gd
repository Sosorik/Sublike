extends CanvasLayer

## 스킬 컷인. 상반신 일러가 슬라이드 인 + 대사 + 화면 플래시. 총 0.6초.
##
## 전투는 멈추지 않는다. 정지 이미지와 Tween 만 쓴다 — 애니메이션 프레임 없음.
## 이게 이 게임의 세일즈 포인트다. 아트 리소스를 늘리지 않고 임팩트를 만드는 유일한 방법.
##
## 연속 발동 시 겹치지 않게 큐에 쌓았다가 차례로 재생한다.

## 컷인 하나가 끝났다.
signal cutin_finished(skill_id: String)

const SLIDE_IN: float = 0.15
const HOLD: float = 0.3
const SLIDE_OUT: float = 0.15

## 화면 밖 / 안 x 좌표.
const OFF_X: float = -480.0
const ON_X: float = 16.0

## 큐가 이보다 길어지면 오래된 것을 버린다. 밀린 컷인을 다 보여줄 이유가 없다.
const MAX_QUEUE: int = 2

## 인스펙터에서 AidaSkills 를 연결한다.
@export var skills: AidaSkills

## 인스펙터에서 Aida 를 연결한다. 슬롯별 컷인 상반신을 여기서 얻는다.
@export var aida: Aida

## 인스펙터에서 각 노드를 연결한다.
@export var panel: Control
@export var portrait: TextureRect
@export var name_label: Label
@export var line_label: Label
@export var flash: ColorRect

var _queue: Array[Dictionary] = []
var _playing: bool = false


func _ready() -> void:
	if panel == null or flash == null:
		push_error("CutinLayer: 인스펙터 연결이 비어 있다.")
		return

	panel.position.x = OFF_X
	flash.color.a = 0.0

	if skills != null:
		skills.skill_used.connect(_on_skill_used)


## 컷인을 재생한다. 재생 중이면 큐에 넣는다.
func play(skill: Dictionary) -> void:
	if skill.is_empty():
		return
	_queue.append(skill)
	while _queue.size() > MAX_QUEUE:
		_queue.pop_front()
	if not _playing:
		_play_next()


func is_playing() -> bool:
	return _playing


## ---------------------------------------------------------------- 내부

func _on_skill_used(_slot: int, skill: Dictionary) -> void:
	play(skill)


func _play_next() -> void:
	if _queue.is_empty():
		_playing = false
		return

	_playing = true
	var skill: Dictionary = _queue.pop_front()
	var tint: Color = Color.from_string(
		str((skill.get("effect", {}) as Dictionary).get("vfx_color", "")),
		Color(0.85, 0.9, 1.0)
	)

	if name_label != null:
		name_label.text = str(skill.get("name", ""))
	if line_label != null:
		line_label.text = str(skill.get("cutin_line", ""))

	# 슬롯마다 다른 표정을 쓴다. 없으면 직전 것을 그대로 둔다.
	if portrait != null:
		var path: String = ""
		if aida != null:
			path = aida.get_cutin_portrait(str(skill.get("slot", "")))
		if not path.is_empty() and ResourceLoader.exists(path):
			portrait.texture = load(path) as Texture2D
			portrait.modulate = Color.WHITE
		else:
			portrait.modulate = tint

	_flash(tint)

	var tween: Tween = create_tween()
	tween.tween_property(panel, "position:x", ON_X, SLIDE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_property(panel, "position:x", OFF_X, SLIDE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_tween_finished.bind(str(skill.get("id", ""))))


func _flash(tint: Color) -> void:
	flash.color = Color(tint.r, tint.g, tint.b, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.35, 0.05)
	tween.tween_property(flash, "color:a", 0.0, 0.25)


func _on_tween_finished(skill_id: String) -> void:
	cutin_finished.emit(skill_id)
	_play_next()
