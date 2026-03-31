extends Node
class_name CardSpawner

@export var card_scene: PackedScene
@export var board_container: Node2D # 카드를 자식으로 붙일 보드 노드 (에디터에서 할당)

func _ready():
	if not card_scene:
		# 기본값 로드 시도
		if ResourceLoader.exists("res://Assets/Scenes/Card/Card.tscn"):
			card_scene = load("res://Assets/Scenes/Card/Card.tscn")
		else:
			push_error("CardSpawner: Card.tscn 씬을 찾을 수 없거나 할당되지 않았습니다.")
			
	if not board_container:
		# 기본적으로는 부모 노드나 현재 씬의 최상위 노드를 사용
		board_container = get_tree().current_scene

# 초기 맵과 주인공 캐릭터 스폰
func spawn_initial_cards():
	spawn_card("char_player", Vector2(-150, 0))
	spawn_card("map_beach", Vector2(150, 0))

func spawn_card(card_id: String, target_position: Vector2, options: Dictionary = {}) -> Node:
	if not card_scene: return null
	
	var new_card = card_scene.instantiate() as Card
	
	if board_container:
		board_container.add_child(new_card)
		new_card.global_position = target_position
	
	new_card.setup(card_id)
	print("[Spawer] Spawned Card: ", card_id, " at ", target_position)
	return new_card

func recycle_card(card: Node):
	# 향후 풀링이 도입되면 여기에 반납 로직 작성
	card.queue_free()

# 탐험 완료 등의 상황에서 위로 톡 튀어오르는(Tween) 연출을 동반하는 스폰
func spawn_card_with_bounce(card_id: String, start_pos: Vector2, target_pos: Vector2) -> Node:
	var new_card = spawn_card(card_id, start_pos)
	if new_card:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# 위로 살짝 포물선을 그리며 떨어지는 연출
		var peak_pos = (start_pos + target_pos) / 2.0 + Vector2(0, -100) # 가운데 지점에서 위로 100픽셀 점프
		
		# 고도 4.x 연쇄 트윈 (시간 분할)
		tween.tween_property(new_card, "global_position", peak_pos, 0.2)
		tween.tween_property(new_card, "global_position", target_pos, 0.2).set_ease(Tween.EASE_IN)
		
	return new_card
