class_name BattleLayout
extends RefCounted

## 전장 좌표 규약.
## docs/ARCHITECTURE.md "좌표 규약" 과 반드시 일치시킨다.
## 여기 값을 바꾸면 문서도 같이 고칠 것.
##
## 레인(가로줄) = 적이 오는 길. PvZ 유래.
## 열(세로줄) = 배치 위치. 명일방주 유래.
## 레인3 × 열3 = 배치 타일 9칸.

## 화면 밖 우측. 적은 여기서 나타나 왼쪽으로 걸어온다.
const SPAWN_X: float = 1400.0

## 아이다 위치. 이동하지 않는다. 가운데 레인에 선다.
const AIDA_X: float = 80.0
const AIDA_Y: float = 348.0

## 적이 이 x보다 왼쪽에 도달하면 아이다가 피해를 입는다.
const AIDA_HIT_X: float = 120.0

## 열 x좌표. 인덱스 0 = 열1 = 가장 오른쪽 = 적을 먼저 만난다.
const COLUMN_X: Array[float] = [680.0, 520.0, 360.0]

## 막힌 타일. 배치할 수 없다.
const BLOCKED: String = "none"

## 지형 문자 → 타일 종류. floors.json 의 layouts 가 이 글자를 쓴다.
const KIND_OF_CHAR: Dictionary = {
	"G": "ground",
	"H": "high",
	".": "none",
}

## 레인 y좌표. 간격 112 — 유닛 스프라이트(약 100)보다 커야 세로로 겹치지 않는다.
const LANE_Y: Array[float] = [236.0, 348.0, 460.0]

## 레인 이름. 데이터·그룹 이름에 쓴다.
const LANES: Array[String] = ["a", "b", "c"]

## 배치 종류.
const GROUND: String = "ground"
const HIGH: String = "high"


## ---------------------------------------------------------------- 타일

static func lane_count() -> int:
	return LANES.size()


static func column_count() -> int:
	return COLUMN_X.size()


## 타일 좌표. lane 은 0~2, column 은 0~2.
static func tile_position(lane_index: int, column_index: int) -> Vector2:
	return Vector2(COLUMN_X[column_index], LANE_Y[lane_index])


## 지형 문자열 배열(레인당 1줄)에서 타일 종류를 읽는다.
## 범위를 벗어나거나 모르는 글자는 막힌 것으로 본다.
static func kind_from_layout(layout: Array, lane_index: int, column_index: int) -> String:
	if lane_index < 0 or lane_index >= layout.size():
		return BLOCKED
	var row: String = str(layout[lane_index])
	if column_index < 0 or column_index >= row.length():
		return BLOCKED
	return str(KIND_OF_CHAR.get(row[column_index], BLOCKED))


## 레인 이름 → 인덱스. 없으면 -1.
static func lane_index_of(lane: String) -> int:
	return LANES.find(lane)


## ---------------------------------------------------------------- 레인

## 해당 레인의 적 스폰 좌표.
static func spawn_position(lane: String) -> Vector2:
	return Vector2(SPAWN_X, lane_y(lane))


## 해당 레인의 y좌표.
static func lane_y(lane: String) -> float:
	var i: int = lane_index_of(lane)
	return LANE_Y[i] if i >= 0 else LANE_Y[0]
