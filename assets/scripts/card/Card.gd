extends Area2D
class_name Card

# [데이터 구조]
var card_id: String = ""
var current_stack: int = 1
var current_durability: int = 100

# [상태 변수]
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# [참조 노드]
# 뷰는 유저가 만들어줄 것이므로, 예상되는 노드들의 참조를 선언합니다.
# 유저가 씬 구성 후 인스펙터에서 할당하거나, 이름이 동일하면 _ready에서 자동 할당됩니다.

func _ready():
	# Area2D에서 마우스 입력을 감지하기 위해 활성화
	input_pickable = true
	
	# 드래그를 위한 입력 이벤트 연결
	if not input_event.is_connected(_on_input_event):
		input_event.connect(_on_input_event)

func setup(id: String, stack: int = 1):
	card_id = id
	current_stack = stack
	# 여기서 리소스 매니저 등을 통해 이미지 등을 업데이트 하도록 호출합니다.

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	# 왼쪽 클릭 드래그 로직 (Area2D 기반 샌드박스 보드 조작용)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 드래그 시작
			is_dragging = true
			drag_offset = position - get_global_mouse_position()
			
			# 시각적으로 맨 위로 올라오도록 Z-Index 조정
			z_index = 100
		else:
			# 드래그 종료 (마우스 뗌)
			is_dragging = false
			z_index = 0
			_on_drop()

func _process(delta: float):
	if is_dragging:
		# 위치 즉각 업데이트
		position = get_global_mouse_position() + drag_offset

func _on_drop():
	# 드래그가 끝났을 때 겹치는 영역 확인
	var overlapping_areas = get_overlapping_areas()
	
	var target_card: Card = null
	for area in overlapping_areas:
		if area is Card and area != self:
			target_card = area
			break
			
	if target_card != null:
		# 대상 카드가 있다면 CraftSystem 쪽에 질의를 던짐. (직접 처리하지 않음)
		# Systems 그룹이나 싱글톤 등 환경에 맞게 CraftSystem을 찾아서 호출
		var craft_system = get_tree().get_first_node_in_group("CraftSystem")
		if craft_system and craft_system.has_method("check_crafting"):
			var result = craft_system.check_crafting(self, target_card)
			if result.get("success", false):
				# 조합 성공 시 연출이나 데이터 정리 진행
				# CardSpawner를 통해 풀에 반납
				pass

func get_save_data() -> Dictionary:
	# SaveManager가 가져갈 동적 변수 반환
	return {
		"card_id": card_id,
		"x": position.x,
		"y": position.y,
		"stack": current_stack,
		"durability": current_durability
	}
