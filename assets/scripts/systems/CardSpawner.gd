extends Node
class_name CardSpawner

# 향후 객체 풀링(Object Pooling)을 쉽게 적용하기 위한 창구.
# 카드가 직접 load() 나 queue_free()를 호출하는 것을 지양하고 이곳을 거치도록 설계.

# var card_scene = preload("res://assets/scenes/card/card_view.tscn")

func spawn_card(card_id: String, target_position: Vector2) -> Node:
	# 인스턴스화 후 데이터 주입 및 필드에 AddChild 수행
	print("Spawn Card: ", card_id, " at ", target_position)
	return null

func recycle_card(card: Node):
	# 풀링을 사용할 경우 여기에 다시 반납하는 로직 추가
	card.queue_free()
