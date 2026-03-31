extends Control
class_name Card

# [데이터 구조]
@export var card_id: String = ""

var current_stack: int = 1
var current_durability: int = 100

# [상태 변수]
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# [참조 노드]
# 겹침 판정을 전담할 Area2D 자식 노드 (이름이 DropSensor인지 확인 필수)
@onready var drop_sensor: Area2D = $DropSensor if has_node("DropSensor") else null

func _ready():
	# 마우스 클릭을 겹친 카드들(형제 노드)에게는 넘기지 않으면서(Block Sibling)
	# 사용되지 않은 우클릭/휠 이벤트 등은 상위 부모 씬으로 넘기기 위해 PASS로 설정합니다.
	mouse_filter = Control.MOUSE_FILTER_PASS

func setup(id: String, stack: int = 1):
	card_id = id
	current_stack = stack
	# 게임 테이블 데이터를 불러와 이미지/이름 등을 UI(자식 구성요소)에 적용

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 드래그 시작
			is_dragging = true
			drag_offset = position - get_global_mouse_position()
			
			z_index = 100 # 맨 위로 보이게 조치
			
			# 엔진에 "핵심 클릭을 이 녀석이 먹었음"을 명시
			accept_event()
		else:
			if is_dragging:
				# 드래그 종료
				is_dragging = false
				z_index = 0
				_on_drop()
				
				# 엔진에 이벤트 소비 명시
				accept_event()

func _process(delta: float):
	if is_dragging:
		# 글로벌 마우스 좌표를 기준으로 UI의 위치 즉각 반영
		position = get_global_mouse_position() + drag_offset

func _on_drop():
	if not drop_sensor:
		push_warning("Card: DropSensor(Area2D)가 없습니다. 겹침 판정이 불가합니다.")
		return
		
	var overlapping_areas = drop_sensor.get_overlapping_areas()
	
	var target_card: Card = null
	for area in overlapping_areas:
		# Area2D의 부모가 Card 타입인지 확인
		var parent = area.get_parent()
		if parent is Card and parent != self:
			target_card = parent
			break
			
	if target_card != null:
		var craft_system = get_tree().get_first_node_in_group("CraftSystem")
		if craft_system and craft_system.has_method("check_interaction"):
			var result = craft_system.check_interaction(self , target_card)
			if result.get("success", false):
				# 조합 성공 시 풀(Pool) 반환 또는 queue_free 처리 등
				pass

func get_save_data() -> Dictionary:
	return {
		"card_id": card_id,
		"x": position.x,
		"y": position.y,
		"stack": current_stack,
		"durability": current_durability
	}
