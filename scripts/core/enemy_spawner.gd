extends Node

## 웨이브 스포너. data/enemies.json 의 wave_pattern 을 그대로 따른다.
##
## 층당 웨이브 5 (waves_per_floor), 웨이브 사이 정비 시간 (intermission_sec).
## 한 층만 돈다. 다음 층으로 넘기는 건 4주차 "층 진행" 항목이다.
##
## 웨이브 클리어 조건 = 스폰 큐가 비었고 살아있는 적이 0.
## 지금은 적을 죽일 수단이 없어서 전부 아이다까지 걸어가야 클리어된다.
## DamagePacket 항목이 붙으면 자연스럽게 "처치로 클리어"가 된다.

## 웨이브가 시작됐다.
signal wave_started(wave_number: int, total_waves: int, enemy_count: int)
## 웨이브의 적이 전부 사라졌다.
signal wave_cleared(wave_number: int)
## 층의 마지막 웨이브까지 끝났다.
signal floor_cleared()
## 적이 아이다까지 갔다. 피해 적용은 Battle 이 한다 — 스포너는 아이다를 몰라도 된다.
signal enemy_reached_aida(enemy: Enemy)
## 보스가 나타났다.
signal boss_appeared(enemy_id: String)

enum State { IDLE, SPAWNING, WAITING_CLEAR, INTERMISSION, DONE }

## 인스펙터에서 scenes/entities/enemy.tscn 을 연결한다.
@export var enemy_scene: PackedScene

## 스폰한 적을 담을 노드. 인스펙터에서 Enemies 를 연결한다.
@export var enemies_root: Node2D

## 전투 시작 전 미리 만들어 둘 적 수. 가장 큰 웨이브보다 넉넉하게.
@export var prewarm_count: int = 24

## false 면 start() 를 직접 불러야 시작한다.
## 층 진행이 붙은 뒤로는 Battle 이 층마다 start() 를 부른다.
@export var auto_start: bool = false

## 스폰 한 마리마다 로그를 찍는다. 검증할 때만 켠다.
@export var verbose: bool = false

## wave_pattern 을 읽지 못했을 때만 쓰는 대비값.
const FALLBACK_INTERMISSION: float = 3.0
const FALLBACK_INTERVAL: float = 1.0
const FALLBACK_MAX_ALIVE: int = 100

var _waves: Array = []
var _rows: Dictionary = {}          ## enemy_id → 데이터 (1회만 복사해서 재사용)
var _queue: Array[String] = []      ## 이번 웨이브에 남은 스폰 목록
var _wave_index: int = -1           ## 0-based
var _alive: int = 0
var _killed: int = 0
var _timer: float = 0.0
var _interval: float = FALLBACK_INTERVAL
var _intermission: float = FALLBACK_INTERMISSION
var _max_alive: int = FALLBACK_MAX_ALIVE
var _lane_index: int = 0
var _state: State = State.IDLE

## 층 난이도. RunState 가 넣어 준다.
var _hp_mult: float = 1.0
var _rate_mult: float = 1.0

## 보스층이면 마지막 웨이브를 클리어한 뒤 보스가 하나 나온다.
var _boss_id: String = ""
var _boss_spawned: bool = false


func _ready() -> void:
	if enemy_scene == null:
		push_error("EnemySpawner: enemy_scene 이 비어 있다.")
		return
	if enemies_root == null:
		push_error("EnemySpawner: enemies_root 가 비어 있다.")
		return

	if not _load_pattern():
		return

	ObjectPool.prewarm(enemy_scene, prewarm_count)
	if auto_start:
		# 자식의 _ready() 는 부모보다 먼저 돈다. 여기서 바로 시작하면
		# 부모가 시그널을 연결하기 전에 1번 웨이브가 시작돼 wave_started 를 놓친다.
		start.call_deferred()


## 이 층의 보스를 정한다. 빈 문자열이면 보스가 없는 평범한 층이다. start() 전에 부른다.
func set_boss(enemy_id: String) -> void:
	_boss_id = enemy_id


## 층 난이도를 넣는다. start() 전에 부른다.
## 적 체력은 배수를 곱하고, 스폰 간격은 배수로 나눈다 (클수록 빨리 나온다).
func set_difficulty(hp_mult: float, rate_mult: float) -> void:
	_hp_mult = maxf(0.01, hp_mult)
	_rate_mult = maxf(0.01, rate_mult)
	_reload_rows()


## 1번 웨이브부터 시작한다.
func start() -> void:
	if _waves.is_empty():
		push_error("EnemySpawner: 웨이브 데이터가 없어 시작할 수 없다.")
		return
	_wave_index = -1
	_alive = 0
	_killed = 0
	_boss_spawned = false
	_queue.clear()
	_next_wave()


## 스폰을 멈춘다. 판이 실패했을 때 쓴다. 이미 나와 있는 적은 그대로 둔다.
func stop() -> void:
	_queue.clear()
	_state = State.IDLE


func get_state() -> State:
	return _state


func get_alive_count() -> int:
	return _alive


## 이번 층에서 처치한 적 수.
func get_killed_count() -> int:
	return _killed


## 현재 웨이브 번호(1-based). 아직 시작 전이면 0.
func get_wave_number() -> int:
	return _wave_index + 1


func _process(delta: float) -> void:
	match _state:
		State.SPAWNING:
			_tick_spawning(delta)
		State.WAITING_CLEAR:
			if _alive <= 0:
				wave_cleared.emit(get_wave_number())
				_timer = _intermission
				_state = State.INTERMISSION
		State.INTERMISSION:
			_timer -= delta
			if _timer <= 0.0:
				_next_wave()
		_:
			pass


## ---------------------------------------------------------------- 내부

func _tick_spawning(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return

	# 화면이 꽉 찼으면 자리가 날 때까지 스폰을 미룬다.
	if _alive >= _max_alive:
		return

	_spawn_one(_queue.pop_front())
	_timer = _interval

	if _queue.is_empty():
		_state = State.WAITING_CLEAR


func _next_wave() -> void:
	_wave_index += 1
	if _wave_index >= _waves.size():
		# 일반 웨이브가 끝났다. 보스층이면 여기서 보스가 나온다.
		if not _boss_id.is_empty() and not _boss_spawned:
			_spawn_boss()
			return
		_state = State.DONE
		floor_cleared.emit()
		return

	var wave: Dictionary = _waves[_wave_index]
	_interval = float(wave.get("spawn_interval", FALLBACK_INTERVAL)) / _rate_mult
	_queue = _build_queue(wave.get("entries", []) as Array)
	_timer = 0.0
	_state = State.SPAWNING
	wave_started.emit(get_wave_number(), _waves.size(), _queue.size())


## 보스 하나만 내보내고 처치될 때까지 기다린다.
func _spawn_boss() -> void:
	_boss_spawned = true
	_queue.clear()
	_spawn_one(_boss_id)
	_state = State.WAITING_CLEAR
	boss_appeared.emit(_boss_id)


## entries 를 스폰 순서 목록으로 편다.
## 종류별로 뭉치지 않도록 번갈아 낸다. 난수를 쓰지 않아 실행마다 결과가 같다.
func _build_queue(entries: Array) -> Array[String]:
	var remaining: Array[int] = []
	var ids: Array[String] = []
	for e in entries:
		var entry: Dictionary = e
		ids.append(str(entry.get("enemy_id", "")))
		remaining.append(int(entry.get("count", 0)))

	var out: Array[String] = []
	var moved: bool = true
	while moved:
		moved = false
		for i in ids.size():
			if remaining[i] > 0:
				out.append(ids[i])
				remaining[i] -= 1
				moved = true
	return out


func _spawn_one(enemy_id: String) -> void:
	var row: Dictionary = _rows.get(enemy_id, {})
	if row.is_empty():
		push_error("EnemySpawner: 알 수 없는 적 '%s'" % enemy_id)
		return

	var enemy: Enemy = ObjectPool.acquire(enemy_scene) as Enemy
	if enemy == null:
		push_error("EnemySpawner: enemy_scene 루트에 enemy.gd 가 없다.")
		return

	# 재사용된 적은 이미 연결돼 있다. 중복 연결하면 시그널이 두 번 온다.
	if not enemy.reached_aida.is_connected(_on_enemy_reached_aida):
		enemy.reached_aida.connect(_on_enemy_reached_aida)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)

	enemy.setup(row)
	enemies_root.add_child(enemy)
	enemy.spawn_at(_pick_lane(enemy.get_lane_pref()))
	_alive += 1

	if verbose:
		print("  스폰 %s lane=%s (alive=%d, 남은 큐=%d)" % [
			enemy.enemy_id, enemy.get_lane(), _alive, _queue.size()
		])


## lane_pref 를 실제 레인으로 바꾼다. "any" 면 순환, 아니면 지정 레인.
## 지정 레인 적은 순환 카운터를 소비하지 않는다.
func _pick_lane(lane_pref: String) -> String:
	if lane_pref != "any":
		if lane_pref in BattleLayout.LANES:
			return lane_pref
		push_warning("EnemySpawner: 알 수 없는 lane_pref '%s'" % lane_pref)

	var lane: String = BattleLayout.LANES[_lane_index]
	_lane_index = (_lane_index + 1) % BattleLayout.LANES.size()
	return lane


func _on_enemy_reached_aida(enemy: Enemy) -> void:
	_alive = maxi(0, _alive - 1)
	# 반납 전에 알린다. 받는 쪽이 enemy.damage 를 읽어야 한다.
	enemy_reached_aida.emit(enemy)
	ObjectPool.release(enemy)


## 적이 처치됐다. 파편 드롭은 Phase 1 범위 밖이라 아직 없다.
func _on_enemy_died(enemy: Enemy) -> void:
	_killed += 1
	_alive = maxi(0, _alive - 1)
	if verbose:
		print("  처치 %s (남은 alive=%d)" % [enemy.enemy_id, _alive])
	ObjectPool.release(enemy)


func _load_pattern() -> bool:
	var pattern: Dictionary = DataLoader.get_wave_pattern()
	if pattern.is_empty():
		push_error("EnemySpawner: wave_pattern 을 읽지 못했다.")
		return false

	_waves = pattern.get("waves", []) as Array
	if _waves.is_empty():
		push_error("EnemySpawner: wave_pattern.waves 가 비어 있다.")
		return false

	var declared: int = int(pattern.get("waves_per_floor", _waves.size()))
	if declared != _waves.size():
		push_warning("EnemySpawner: waves_per_floor(%d) 와 waves 개수(%d) 가 다르다." % [
			declared, _waves.size()
		])

	_intermission = float(pattern.get("intermission_sec", FALLBACK_INTERMISSION))
	_max_alive = int(pattern.get("max_alive", FALLBACK_MAX_ALIVE))

	_reload_rows()
	return true


## 적 데이터를 다시 읽어 층 난이도를 반영한다.
## 원본이 아니라 복사본을 고치는 것이라 JSON 은 그대로다.
func _reload_rows() -> void:
	_rows.clear()
	for id in DataLoader.ids(DataLoader.GROUP_ENEMIES):
		var row: Dictionary = DataLoader.get_enemy(id)
		row["hp"] = float(row.get("hp", 1.0)) * _hp_mult
		_rows[id] = row
