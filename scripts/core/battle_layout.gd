class_name BattleLayout
extends RefCounted

## 전장 좌표 규약.
## docs/ARCHITECTURE.md "좌표 규약"과 반드시 일치시킨다.
## 여기 값을 바꾸면 문서도 같이 고칠 것.

## 화면 밖 우측. 적은 여기서 나타나 왼쪽으로 걸어온다.
const SPAWN_X: float = 1400.0

## 아이다 위치. 이동하지 않는다.
const AIDA_X: float = 80.0
const AIDA_Y: float = 300.0

## 적이 이 x보다 왼쪽에 도달하면 아이다가 피해를 입는다.
const AIDA_HIT_X: float = 120.0

## 라인별 가신 슬롯 x좌표.
## 전열이 가장 오른쪽 = 적을 먼저 만나 저지한다.
const LINE_X: Dictionary = {
	"front": 600.0,
	"mid": 450.0,
	"back": 300.0,
}

## 레인별 y좌표. 적은 스폰된 레인을 따라 직진하며 레인을 바꾸지 않는다.
const LANE_Y: Dictionary = {
	"front": 380.0,
	"mid": 300.0,
	"back": 220.0,
}

## 라인 이름 목록. 화면 위(back)에서 아래(front) 순서가 아니라
## 데이터 파일과 같은 순서로 둔다.
const LINES: Array[String] = ["front", "mid", "back"]


## 해당 라인의 가신 슬롯 좌표.
static func slot_position(line: String) -> Vector2:
	return Vector2(float(LINE_X[line]), float(LANE_Y[line]))


## 해당 레인의 적 스폰 좌표.
static func spawn_position(lane: String) -> Vector2:
	return Vector2(SPAWN_X, float(LANE_Y[lane]))


## 해당 레인의 y좌표.
static func lane_y(lane: String) -> float:
	return float(LANE_Y[lane])
