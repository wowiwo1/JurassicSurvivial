extends Camera2D

# 줌 인/아웃 범위 설정
const MIN_ZOOM: Vector2 = Vector2(0.3, 0.3)
const MAX_ZOOM: Vector2 = Vector2(2.5, 2.5)
const ZOOM_SPEED: Vector2 = Vector2(0.4, 0.4)
const ZOOM_LERP_SPEED: float = 12.0 # 수치가 클수록 더 빨리 따라붙습니다.

var target_zoom: Vector2 = Vector2.ONE

# 패닝 관련 변수
var is_panning: bool = false
var pan_start_mouse_pos: Vector2 = Vector2.ZERO
var pan_start_camera_pos: Vector2 = Vector2.ZERO

func _ready():
	target_zoom = zoom
	# 포지션 최신화 보장 (매끄러운 카메라)
	position_smoothing_enabled = true
	position_smoothing_speed = 15.0

func _process(delta: float):
	# 카메라 줌 부드러운 선형 보간 (Lerp / Ease-out 느낌)
	if zoom.distance_to(target_zoom) > 0.001:
		zoom = zoom.lerp(target_zoom, ZOOM_LERP_SPEED * delta)

func _unhandled_input(event: InputEvent):
	# 1. 휠 줌(Zoom) 기능
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				apply_zoom(ZOOM_SPEED)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				apply_zoom(-ZOOM_SPEED)
				
		# 2. 패닝(우클릭 혹은 휠 클릭으로 드래그)
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.is_pressed():
				is_panning = true
				pan_start_mouse_pos = get_viewport().get_mouse_position()
				pan_start_camera_pos = position
			else:
				is_panning = false

	# 패닝 중 마우스 이동
	if event is InputEventMouseMotion and is_panning:
		var mouse_delta = get_viewport().get_mouse_position() - pan_start_mouse_pos
		# 부드러운 줌잉 상태를 반영해 실제 현재 zoom 수치에 맞춰 위치 계산
		position = pan_start_camera_pos - (mouse_delta / zoom)

func apply_zoom(zoom_factor: Vector2):
	target_zoom += zoom_factor
	target_zoom.x = clamp(target_zoom.x, MIN_ZOOM.x, MAX_ZOOM.x)
	target_zoom.y = clamp(target_zoom.y, MIN_ZOOM.y, MAX_ZOOM.y)
