extends Node

# 기획 데이터(GameTable)를 바탕으로 내부 상태 이상 및 수치 갱신
# 만능 조건 검사기 역할

var current_hunger: float = 100.0
var current_fatigue: float = 0.0

func _ready():
	# 여기서 게임 테이블 데이터를 로드 (예: action_table.tres)
	pass

# 다른 노드에서 직접 리턴(True/False)이 필요할 때 호출
func query(query_type: String, params: Dictionary = {}) -> Variant:
	match query_type:
		"can_explore":
			return current_fatigue < 100.0
		"can_craft":
			return true
	return false
