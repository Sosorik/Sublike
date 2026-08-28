extends CanvasLayer

## 전투 HUD. 아이다 체력 + 액티브 버튼 3개 + 쿨타임 게이지 + 자동 시전 토글.
##
## 버튼 위젯은 코드로 만든다. 슬롯 3개가 똑같은 모양이라 씬에 3벌 복사해 두면
## 한 곳만 고쳐도 나머지가 어긋난다. 정식 아트가 나오면 씬으로 옮긴다.
##
## 키보드 1 / 2 / 3 으로도 쓸 수 있다. 모바일은 터치지만 개발 중엔 이게 빠르다.

## 인스펙터에서 AidaSkills 를 연결한다.
@export var skills: AidaSkills

## 인스펙터에서 Aida 를 연결한다.
@export var aida: Aida

## 인스펙터에서 RunState / EnemySpawner / Battle 을 연결한다.
@export var run_state: RunState
@export var spawner: Node
@export var battle: Node2D

## 인스펙터에서 Status (Label) 를 연결한다. 층·웨이브 표시.
@export var status_label: Label

## 판이 끝났을 때 뜨는 판. 인스펙터에서 Result 계열을 연결한다.
@export var result_panel: Control
@export var result_label: Label
@export var retry_button: Button

## 인스펙터에서 Slots (HBoxContainer) 를 연결한다.
@export var slots_box: HBoxContainer

## 인스펙터에서 AutoCast (CheckBox) 를 연결한다.
@export var auto_cast_box: CheckBox

## 인스펙터에서 AidaHP (ProgressBar) 를 연결한다.
@export var hp_bar: ProgressBar

const SLOT_WIDTH: float = 150.0
const SLOT_HEIGHT: float = 74.0

var _buttons: Array[Button] = []
var _gauges: Array[ProgressBar] = []


func _ready() -> void:
	if skills == null or aida == null or slots_box == null:
		push_error("BattleHUD: 인스펙터 연결이 비어 있다.")
		return

	_build_slots()

	skills.cooldown_changed.connect(_on_cooldown_changed)
	skills.skill_used.connect(_on_skill_used)
	skills.auto_cast_changed.connect(_on_auto_cast_changed)

	aida.hp_changed.connect(_on_aida_hp_changed)
	_on_aida_hp_changed(aida.hp, aida.max_hp)

	if auto_cast_box != null:
		auto_cast_box.toggled.connect(_on_auto_cast_box_toggled)

	if result_panel != null:
		result_panel.visible = false
	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)

	if run_state != null:
		run_state.floor_changed.connect(_on_floor_changed)
		run_state.segment_cleared.connect(_on_segment_cleared)
	if spawner != null:
		spawner.wave_started.connect(_on_wave_started)
	aida.died.connect(_on_aida_died)
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = (event as InputEventKey).keycode
	match key:
		KEY_1: skills.try_use(0)
		KEY_2: skills.try_use(1)
		KEY_3: skills.try_use(2)
		KEY_A: skills.toggle_auto_cast()
		KEY_R:
			if result_panel != null and result_panel.visible:
				_on_retry_pressed()


## ---------------------------------------------------------------- 내부

func _build_slots() -> void:
	for i in AidaSkills.SLOTS.size():
		var skill: Dictionary = skills.get_skill(i)

		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)

		var button := Button.new()
		button.custom_minimum_size = Vector2(SLOT_WIDTH, 48.0)
		button.text = "%d. %s" % [i + 1, skill.get("name", "(없음)")]
		button.disabled = skill.is_empty()
		button.focus_mode = Control.FOCUS_NONE   # 스페이스바가 버튼을 누르지 않게
		button.pressed.connect(_on_slot_pressed.bind(i))
		box.add_child(button)

		var gauge := ProgressBar.new()
		gauge.custom_minimum_size = Vector2(SLOT_WIDTH, 10.0)
		gauge.min_value = 0.0
		gauge.max_value = 1.0
		gauge.value = 1.0
		gauge.show_percentage = false
		box.add_child(gauge)

		slots_box.add_child(box)
		_buttons.append(button)
		_gauges.append(gauge)


func _on_slot_pressed(slot: int) -> void:
	skills.try_use(slot)


## 게이지는 "얼마나 찼는가" 를 보여준다. 1.0 이면 지금 쓸 수 있다.
func _on_cooldown_changed(slot: int, remaining: float, total: float) -> void:
	if slot < 0 or slot >= _gauges.size():
		return
	var filled: float = 1.0 if total <= 0.0 else clampf(1.0 - remaining / total, 0.0, 1.0)
	_gauges[slot].value = filled
	_buttons[slot].disabled = skills.get_skill(slot).is_empty() or remaining > 0.0


func _on_skill_used(slot: int, skill: Dictionary) -> void:
	print("스킬 — %s (슬롯 %d)" % [skill.get("name", "?"), slot + 1])


func _on_auto_cast_changed(enabled: bool) -> void:
	if auto_cast_box != null and auto_cast_box.button_pressed != enabled:
		auto_cast_box.button_pressed = enabled


func _on_auto_cast_box_toggled(pressed: bool) -> void:
	skills.set_auto_cast(pressed)


## ---------------------------------------------------------------- 진행 표시

var _floor_text: String = ""
var _wave_text: String = ""


func _on_floor_changed(floor_number: int, position: int, total: int) -> void:
	_floor_text = "%d층 (%d/%d)" % [floor_number, position, total]
	_wave_text = ""
	_refresh_status()


func _on_wave_started(wave_number: int, total_waves: int, _count: int) -> void:
	_wave_text = "웨이브 %d/%d" % [wave_number, total_waves]
	_refresh_status()


func _refresh_status() -> void:
	if status_label == null:
		return
	status_label.text = _floor_text if _wave_text.is_empty() else "%s   %s" % [_floor_text, _wave_text]


func _on_aida_died() -> void:
	_show_result("실패
아이다가 쓰러졌다")


func _on_segment_cleared() -> void:
	_show_result("구간 클리어
%d층 전부 돌파" % run_state.total_floors())


func _show_result(text: String) -> void:
	if result_panel == null:
		return
	if result_label != null:
		result_label.text = text
	result_panel.visible = true


func _on_retry_pressed() -> void:
	if battle != null:
		battle.retry()


func _on_aida_hp_changed(hp: float, max_hp: float) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_hp
	hp_bar.value = hp
