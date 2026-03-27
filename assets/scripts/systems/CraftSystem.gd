extends Node
class_name CraftSystem

# 카드가 던져주는 "A카드와 B카드가 합쳐질래" 질의에 대해 데이터를 검증
# 재료 소모량과 결과 카드 ID만을 반환

func check_crafting(dragged_card: Node, target_card: Node) -> Dictionary:
	# 성공 시 예시 반환값: {"success": true, "result_id": "crafted_item_01"}
	return {"success": false}
