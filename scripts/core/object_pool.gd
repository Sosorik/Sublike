extends Node

## 오브젝트 풀. autoload 이름: ObjectPool
##
## 전투 중 instantiate() / queue_free() 를 금지한다.
## 적 100마리 + 투사체 200개가 동시에 뜨는 게 목표치다. (docs/ARCHITECTURE.md "오브젝트 풀")
##
## PackedScene 하나당 풀 하나. acquire() 로 꺼내고 release() 로 돌려준다.
## 돌려준 노드는 트리에서 빠지므로 _process / _physics_process 가 돌지 않는다.
##
## 풀에 들어가는 노드는 아래 두 콜백을 선택적으로 가질 수 있다.
##   _on_acquired()   풀에서 나올 때
##   _on_released()   풀로 돌아갈 때 ← 상태 초기화는 여기서 한다

## 풀 하나가 보관할 수 있는 최대 수. 이보다 많이 반납되면 그냥 free 한다.
const MAX_IDLE_PER_SCENE: int = 256

var _idle: Dictionary = {}      ## scene 경로 → Array[Node]
var _busy_count: Dictionary = {}  ## scene 경로 → 사용 중인 개수
var _created: Dictionary = {}     ## scene 경로 → 지금까지 instantiate 한 총 개수


## 미리 만들어 둔다. 전투 시작 전에 호출해서 첫 스폰의 끊김을 없앤다.
func prewarm(scene: PackedScene, count: int) -> void:
	if scene == null:
		push_error("ObjectPool.prewarm: scene 이 null 이다.")
		return
	var key: String = _key(scene)
	var bucket: Array = _bucket(key)
	for i in count:
		if bucket.size() >= MAX_IDLE_PER_SCENE:
			break
		bucket.append(_instantiate(scene, key))


## 풀에서 하나 꺼낸다. 비어 있으면 새로 만든다. 트리에는 호출자가 붙인다.
func acquire(scene: PackedScene) -> Node:
	if scene == null:
		push_error("ObjectPool.acquire: scene 이 null 이다.")
		return null

	var key: String = _key(scene)
	var bucket: Array = _bucket(key)

	var node: Node = null
	while node == null and not bucket.is_empty():
		node = bucket.pop_back()
		if not is_instance_valid(node):
			node = null

	if node == null:
		node = _instantiate(scene, key)

	# 물리 콜백 중 반납이라 트리에서 못 뗀 경우가 있다. 여기서 확실히 떼고 내보낸다.
	var stale_parent: Node = node.get_parent()
	if stale_parent != null:
		stale_parent.remove_child(node)

	node.set_meta("_pool_idle", false)
	_busy_count[key] = int(_busy_count.get(key, 0)) + 1

	if node.has_method("_on_acquired"):
		node.call("_on_acquired")
	return node


## 풀에 돌려준다. 트리에 붙어 있으면 떼어낸다.
func release(node: Node) -> void:
	if not is_instance_valid(node):
		return

	var key: String = str(node.get_meta("_pool_key", ""))
	if key.is_empty():
		push_error("ObjectPool.release: 풀에서 나온 노드가 아니다 — %s" % node.name)
		node.queue_free()
		return

	# 이중 반납은 풀을 조용히 망가뜨린다 (같은 노드가 두 번 대기열에 들어간다).
	if bool(node.get_meta("_pool_idle", false)):
		push_error("ObjectPool.release: 이미 반납된 노드다 — %s" % node.name)
		return
	node.set_meta("_pool_idle", true)

	if node.has_method("_on_released"):
		node.call("_on_released")

	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)

	_busy_count[key] = maxi(0, int(_busy_count.get(key, 0)) - 1)

	var bucket: Array = _bucket(key)
	if bucket.size() >= MAX_IDLE_PER_SCENE:
		node.queue_free()
		return
	bucket.append(node)


## 사용 중 / 대기 중 / 총 생성 수. 성능 확인용.
func stats() -> Dictionary:
	var out: Dictionary = {}
	for key in _created:
		out[key] = {
			"busy": int(_busy_count.get(key, 0)),
			"idle": (_idle.get(key, []) as Array).size(),
			"created": int(_created[key]),
		}
	return out


## 대기 중인 노드를 전부 해제한다. 전투 종료 후 로비로 나갈 때 쓴다.
func clear_idle() -> void:
	for key in _idle:
		for node in (_idle[key] as Array):
			if is_instance_valid(node):
				node.queue_free()
		(_idle[key] as Array).clear()


func _exit_tree() -> void:
	clear_idle()


## ---------------------------------------------------------------- 내부

func _key(scene: PackedScene) -> String:
	var path: String = scene.resource_path
	if path.is_empty():
		# 디스크에 없는 씬. 인스턴스 ID로 구분한다.
		path = "rid:%d" % scene.get_instance_id()
	return path


func _bucket(key: String) -> Array:
	if not _idle.has(key):
		_idle[key] = []
	return _idle[key]


func _instantiate(scene: PackedScene, key: String) -> Node:
	var node: Node = scene.instantiate()
	node.set_meta("_pool_key", key)
	_created[key] = int(_created.get(key, 0)) + 1
	return node
