extends Node
class_name CraftSystem

# 카드가 던져주는 "A카드와 B카드가 합쳐질래" 질의에 대한 마스터 라우터 시스템

func check_interaction(dragged_card: Card, target_card: Card) -> Dictionary:
	# 1. 탐험(Explore) 체크: 캐릭터 -> 맵 구역
	if dragged_card.card_id.begins_with("char_") and target_card.card_id.begins_with("map_"):
		var explore_sys = get_tree().get_first_node_in_group("ExploreSystem")
		if explore_sys:
			explore_sys.start_exploration(dragged_card, target_card)
			# 드래그한 카드가 맵 위 중앙 쯤에 정착(Snap)되도록 위치 조정
			dragged_card.global_position = target_card.global_position + Vector2(20, -20)
			return {"success": true, "type": "explore"}
			
	# 2. 조합(Crafting) 로직 (아이템 + 아이템)
	if dragged_card.card_id.begins_with("item_") and target_card.card_id.begins_with("item_"):
		return execute_crafting(dragged_card, target_card)
		
	# 3. 아이템 사용 로직 (소모품 + 캐릭터)
	# GameTable Action 연동 구역
	if dragged_card.card_id.begins_with("item_") and target_card.card_id.begins_with("char_"):
		# StatusManager를 통해 포만감 회복 등을 처리
		print("[Action] 아이템 사용: ", dragged_card.card_id, " on ", target_card.card_id)
		# 사용 효과 즉시 처리 및 재료 파기
		var spawner = get_tree().get_first_node_in_group("CardSpawner")
		if spawner: spawner.recycle_card(dragged_card)
		return {"success": true, "type": "action"}

	# 교집합 없음 - 아무 동작 안 함
	return {"success": false}

func execute_crafting(dragged_card: Card, target_card: Card) -> Dictionary:
	print("[Craft] 조합 검사: ", dragged_card.card_id, " + ", target_card.card_id)
	
	# 임시 하드코딩된 레시피 표 (GameTable 연동 필요!)
	var recipe_result = ""
	var combo = [dragged_card.card_id, target_card.card_id]
	if "item_wood" in combo and "item_stone" in combo:
		recipe_result = "tool_axe" # 장작 + 돌 = 도끼
		
	if recipe_result != "":
		# 크래프팅 성공! 
		# 기존 재료 카드를 파기하고 완성품 스폰
		var spawner = get_tree().get_first_node_in_group("CardSpawner")
		if spawner:
			var craft_pos = target_card.global_position
			spawner.recycle_card(dragged_card)
			spawner.recycle_card(target_card)
			# 스폰
			spawner.spawn_card(recipe_result, craft_pos)
			
		return {"success": true, "type": "craft", "result_id": recipe_result}
	
	return {"success": false}
