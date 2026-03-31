extends Node
class_name ExploreSystem

# 탐험 드랍 전담. 
# 현재는 하드코딩된 예시를 시연하며, 추후 GameTable의 드랍 확률 로직을 연동.

signal explore_started(character_card: Card, map_card: Card)
signal explore_finished(map_card: Card, generated_card_ids: Array)

func check_exploration(dragged_card: Card, target_card: Card) -> bool:
	# 캐릭터 카드를 맵 카드 위에 올렸을 때 탐험 시작
	# 임시 구분: 'char_' 와 'map_' 접두사로 판별
	if dragged_card.card_id.begins_with("char_") and target_card.card_id.begins_with("map_"):
		start_exploration(dragged_card, target_card)
		return true
	return false

func start_exploration(character: Card, map_card: Card):
	print("[Explore] 탐험 시작: ", character.card_id, " -> ", map_card.card_id)
	explore_started.emit(character, map_card)
	
	# 여기서 캐릭터 카드는 탐험 진행 중 상태(진행 바 표시 등)로 변함
	# 3초간의 임시 탐험 대기 타이머
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_explore_timer_timeout.bind(map_card))

func _on_explore_timer_timeout(map_card: Card):
	# 임시 결과 도출 로직. 실제로는 테이블 확률 데이터로 계산
	var drops = calculate_explore_drops(map_card.card_id)
	
	print("[Explore] 탐험 완료! 드랍 아이템 목록: ", drops)
	explore_finished.emit(map_card, drops)
	
	# CardSpawner를 찾아 결과 아이템들을 보드 필드 위에 흩뿌림
	var spawner = get_tree().get_first_node_in_group("CardSpawner")
	if spawner and spawner.has_method("spawn_card_with_bounce"):
		for i in range(drops.size()):
			# 맵 주변에 흩뿌려질 랜덤 타겟 위치 계산
			var offset = Vector2(randf_range(-150, 150), randf_range(50, 150))
			var target_pos = map_card.global_position + offset
			
			spawner.spawn_card_with_bounce(drops[i], map_card.global_position, target_pos)

func calculate_explore_drops(target_resource_id: String) -> Array:
	# 더미 데이터 생성기 (나중에 GameTable 연동)
	if target_resource_id == "map_beach":
		return ["item_wood", "item_stone"]
	return ["item_trash"]
