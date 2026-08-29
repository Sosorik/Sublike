extends Node2D

## 전투 씬 루트. 층 진행을 지휘한다.
##
## 스폰은 EnemySpawner, 편성은 Party, 진행 상태는 RunState 가 맡는다.
## 여기서는 그것들을 이어 붙이고 층을 넘긴다.
##
## 층 클리어 → 다음 층. 마지막 층까지 끝나면 구간 클리어.
## 아이다가 쓰러지면 실패 — 스폰을 멈추고 리트라이를 기다린다.

## 인스펙터에서 EnemySpawner 노드를 연결한다.
@export var spawner: Node

## 인스펙터에서 Party 노드를 연결한다.
@export var party: Node

## 인스펙터에서 Aida 노드를 연결한다.
@export var aida: Aida

## 인스펙터에서 RunState 노드를 연결한다.
@export var run_state: RunState

## 인스펙터에서 AidaSkills 를 연결한다. 런 강화가 쿨타임·힐량에 붙는다.
@export var skills: AidaSkills

## 인스펙터에서 CutinLayer 를 연결한다. 소환 연출이 여기서 나온다.
@export var cutin: CanvasLayer

## 인스펙터에서 Effects 노드를 연결한다. 피해 숫자·파티클이 여기 담긴다.
@export var effects_root: Node2D

## 층 클리어 후 강화 3택을 내민다. (강화 ID 목록)
signal upgrades_offered(ids: Array)

## 아이다 피해선을 그린다. 완성 전 끈다.
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

	if aida == null:
		push_error("Battle: aida 가 비어 있다. 인스펙터에서 Aida 를 연결할 것.")
		return
	spawner.enemy_reached_aida.connect(_on_enemy_reached_aida)
	aida.hp_changed.connect(_on_aida_hp_changed)
	aida.died.connect(_on_aida_died)

	if run_state == null:
		push_error("Battle: run_state 가 비어 있다. 인스펙터에서 RunState 를 연결할 것.")
		return
	run_state.segment_cleared.connect(_on_segment_cleared)
	spawner.boss_appeared.connect(_on_boss_appeared)
	spawner.enemy_killed.connect(_on_enemy_killed)

	if effects_root != null:
		Effects.set_root(effects_root)
	# 자식들이 다 준비된 뒤 첫 층을 연다.
	_start_floor.call_deferred()


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
	print("=== 실패 — %d층 웨이브 %d 에서 아이다 쓰러짐 (처치 %d) ===" % [
		run_state.current_floor(), spawner.get_wave_number(), spawner.get_killed_count()
	])
	spawner.stop()


## 판을 처음부터 다시. 씬을 통째로 다시 읽는 게 가장 확실하다 —
## 쓰러진 가신, 남은 적, 풀 상태, 버프까지 전부 초기화된다.
func retry() -> void:
	get_tree().reload_current_scene()


func _on_wave_started(wave_number: int, total_waves: int, enemy_count: int) -> void:
	print("웨이브 %d/%d 시작 — 적 %d마리" % [wave_number, total_waves, enemy_count])


func _on_wave_cleared(wave_number: int) -> void:
	print("웨이브 %d 클리어 — 누적 처치 %d" % [wave_number, spawner.get_killed_count()])


## 이번 층의 난이도를 스포너에 넣고 웨이브를 시작한다.
func _start_floor() -> void:
	run_state.announce()
	spawner.set_difficulty(run_state.enemy_hp_mult(), run_state.spawn_rate_mult())
	spawner.set_boss(run_state.boss_enemy_id() if run_state.is_boss_floor() else "")
	print("─── %d층 (%d/%d) 시작 — 적 체력 ×%.2f, 스폰 ×%.2f%s" % [
		run_state.current_floor(), run_state.floor_position(), run_state.total_floors(),
		run_state.enemy_hp_mult(), run_state.spawn_rate_mult(),
		"  [보스층]" if run_state.is_boss_floor() else ""
	])
	spawner.start()


## 처치 보상을 파티로 넘긴다. 선봉이 잡았으면 DP가 들어온다.
func _on_enemy_killed(_enemy: Enemy, killer_hero_id: String) -> void:
	party.on_enemy_killed(killer_hero_id)


func _on_boss_appeared(enemy_id: String) -> void:
	var row: Dictionary = DataLoader.get_enemy(enemy_id)
	print("!!! 보스 등장 — %s (hp %.0f) !!!" % [row.get("name", enemy_id), row.get("hp", 0.0)])


func _on_floor_cleared() -> void:
	print("%d층 클리어 — 처치 %d" % [run_state.current_floor(), spawner.get_killed_count()])

	# 마지막 층이었으면 강화를 고를 이유가 없다. 보스 격파 연출 후 구간 클리어로.
	if run_state.floor_position() >= run_state.total_floors():
		if run_state.is_boss_floor() and _play_summon():
			return   # 연출이 끝나면 _on_summon_finished 가 이어받는다
		run_state.advance()
		return

	var choices: Array[String] = run_state.roll_upgrade_choices(3)
	if choices.is_empty():
		_next_floor()
		return

	# 고르는 동안 전투를 멈춘다. 웨이브 사이 정비 시간과 같은 성격이다.
	get_tree().paused = true
	upgrades_offered.emit(choices)


## 강화를 하나 고른다. HUD 가 부른다.
func choose_upgrade(upgrade_id: String) -> void:
	if run_state.add_upgrade(upgrade_id):
		var row: Dictionary = DataLoader.get_upgrade(upgrade_id)
		print("강화 획득 — %s (스택 %d)" % [
			row.get("name", upgrade_id), run_state.get_upgrade_stack(upgrade_id)
		])
		_apply_run_upgrades()
	get_tree().paused = false
	_next_floor()


func _next_floor() -> void:
	if run_state.advance():
		_start_floor()


## 보스를 격파해 가신을 얻는 연출. 재생을 시작했으면 true.
func _play_summon() -> bool:
	var hero_id: String = run_state.boss_hero_id()
	if cutin == null or hero_id.is_empty():
		return false

	var hero: Dictionary = DataLoader.get_hero(hero_id)
	if hero.is_empty():
		return false

	print("=== 소환 — %s 합류 ===" % hero.get("name", hero_id))
	if not cutin.summon_finished.is_connected(_on_summon_finished):
		cutin.summon_finished.connect(_on_summon_finished, CONNECT_ONE_SHOT)
	cutin.play_summon(
		str(hero.get("portrait", "")),
		str(hero.get("name", hero_id)),
		str(hero.get("cutin_line", ""))
	)
	return true


func _on_summon_finished() -> void:
	run_state.advance()


## 누적된 런 강화를 가신·아이다·스킬에 통째로 다시 반영한다.
func _apply_run_upgrades() -> void:
	party.apply_run_upgrades(run_state)
	aida.set_run_bonus_hp(run_state.upgrade_add("aida_hp_add"))
	if skills != null:
		skills.set_run_modifiers(
			run_state.upgrade_mult("cooldown_mult"),
			run_state.upgrade_add("element_duration_add"),
			run_state.upgrade_mult("heal_mult")
		)


func _on_segment_cleared() -> void:
	print("=== 구간 클리어 — %d층 전부 돌파 ===" % run_state.total_floors())
	spawner.stop()


## 아이다 피해선만 그린다. 배치 격자는 DeployField 가 그린다.
func _draw() -> void:
	if not debug_draw:
		return

	var hit_color := Color(1.0, 0.3, 0.3, 0.5)
	# 아이다 피해선
	draw_line(
		Vector2(BattleLayout.AIDA_HIT_X, 0.0),
		Vector2(BattleLayout.AIDA_HIT_X, 720.0),
		hit_color,
		3.0
	)
	# 아이다는 전신 스프라이트가 서 있다. 체력은 HUD 좌상단에 있다.
