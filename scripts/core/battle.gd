extends Node2D

## 전투 씬 루트.
##
## 스폰은 EnemySpawner 가 전담한다. 여기서는 진행 상황 로그와 레인 안내선만 담당한다.
## 아이다 HP / 실패 처리는 2주차 마지막 항목.

## 인스펙터에서 EnemySpawner 노드를 연결한다.
@export var spawner: Node

## 인스펙터에서 Party 노드를 연결한다.
@export var party: Node

## 인스펙터에서 Aida 노드를 연결한다.
@export var aida: Aida

## 레인 안내선을 그린다. 좌표 확인용 임시 표시. 완성 전 끈다.
@export var debug_draw: bool = true


func _ready() -> void:
	if spawner == null:
		push_error("Battle: spawner 가 비어 있다. 인스펙터에서 EnemySpawner 를 연결할 것.")
		return

	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.floor_cleared.connect(_on_floor_cleared)

	if party == null:
		push_error("Battle: party 가 비어 있다. 인스펙터에서 Party 를 연결할 것.")
		return
	party.party_placed.connect(_on_party_placed)

	if aida == null:
		push_error("Battle: aida 가 비어 있다. 인스펙터에서 Aida 를 연결할 것.")
		return
	spawner.enemy_reached_aida.connect(_on_enemy_reached_aida)
	aida.hp_changed.connect(_on_aida_hp_changed)
	aida.died.connect(_on_aida_died)


func _on_party_placed(units: Array) -> void:
	print("편성 완료 — 가신 %d명" % units.size())


## 적이 아이다까지 갔다. 적의 damage 로 피해 묶음을 만들어 넘긴다.
## source_hero_id 는 비워 둔다 — 가신이 준 피해가 아니다.
func _on_enemy_reached_aida(enemy: Enemy) -> void:
	if not aida.is_alive():
		return
	# 피해 로그가 먼저 나와야 읽힌다. take_damage 는 hp_changed 를 즉시 쏜다.
	print("돌파 — %s 아이다 피해 %.0f" % [enemy.display_name, enemy.damage])
	aida.take_damage(DamagePacket.new(enemy.damage, false, ""))


func _on_aida_hp_changed(hp: float, max_hp: float) -> void:
	queue_redraw()   # 디버그 체력바를 다시 그린다
	if hp > 0.0:
		print("  아이다 HP %.0f/%.0f" % [hp, max_hp])


func _on_aida_died() -> void:
	print("=== 실패 — 아이다 쓰러짐. 웨이브 %d 진행 중, 처치 %d ===" % [
		spawner.get_wave_number(), spawner.get_killed_count()
	])
	spawner.stop()
	# 리트라이는 4주차 "실패 / 리트라이" 항목이다.


func _on_wave_started(wave_number: int, total_waves: int, enemy_count: int) -> void:
	print("웨이브 %d/%d 시작 — 적 %d마리" % [wave_number, total_waves, enemy_count])


func _on_wave_cleared(wave_number: int) -> void:
	print("웨이브 %d 클리어 — 누적 처치 %d" % [wave_number, spawner.get_killed_count()])


func _on_floor_cleared() -> void:
	print("층 클리어 — 강화 3택은 4주차 항목")


## 레인 안내선. 좌표가 문서와 맞는지 눈으로 확인하기 위한 임시 표시.
func _draw() -> void:
	if not debug_draw:
		return

	var lane_color := Color(1.0, 1.0, 1.0, 0.12)
	var slot_color := Color(0.4, 0.8, 1.0, 0.9)
	var hit_color := Color(1.0, 0.3, 0.3, 0.5)

	for line in BattleLayout.LINES:
		var y: float = BattleLayout.lane_y(line)
		draw_line(Vector2(0.0, y), Vector2(1280.0, y), lane_color, 2.0)
		draw_circle(BattleLayout.slot_position(line), 12.0, slot_color)

	# 아이다 피해선
	draw_line(
		Vector2(BattleLayout.AIDA_HIT_X, 0.0),
		Vector2(BattleLayout.AIDA_HIT_X, 720.0),
		hit_color,
		3.0
	)
	# 아이다 위치 + 체력바 (임시 표시. 정식 HUD 는 3주차)
	var aida_pos := Vector2(BattleLayout.AIDA_X, BattleLayout.AIDA_Y)
	var ratio: float = aida.get_hp_ratio() if aida != null else 1.0
	var body_color := Color(0.6, 1.0, 0.6, 0.9) if ratio > 0.0 else Color(0.4, 0.4, 0.4, 0.9)
	draw_circle(aida_pos, 16.0, body_color)

	var bar_size := Vector2(60.0, 8.0)
	var bar_top := aida_pos + Vector2(-bar_size.x * 0.5, -34.0)
	draw_rect(Rect2(bar_top, bar_size), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(
		Rect2(bar_top, Vector2(bar_size.x * ratio, bar_size.y)),
		Color(0.4, 0.9, 0.4, 0.95) if ratio > 0.3 else Color(0.95, 0.35, 0.3, 0.95)
	)
