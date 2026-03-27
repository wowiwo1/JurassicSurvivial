@tool
extends EditorPlugin

var connected_nodes: Array[Control] = []
var last_workspace: String = "2D"

func _enter_tree():
	main_screen_changed.connect(_on_main_screen_changed)
	var fs_dock = EditorInterface.get_file_system_dock()
	_connect_inputs(fs_dock)

func _on_main_screen_changed(screen_name: String):
	if screen_name in ["2D", "3D"]:
		last_workspace = screen_name

func _exit_tree():
	if main_screen_changed.is_connected(_on_main_screen_changed):
		main_screen_changed.disconnect(_on_main_screen_changed)
		
	for node in connected_nodes:
		if is_instance_valid(node) and node.gui_input.is_connected(_on_gui_input):
			node.gui_input.disconnect(_on_gui_input)
	connected_nodes.clear()

func _connect_inputs(node: Node):
	# 파일 시스템의 폴더/파일 목록 UI를 찾아 입력 이벤트를 가로챕니다.
	if node is Tree or node is ItemList:
		if not node.gui_input.is_connected(_on_gui_input):
			node.gui_input.connect(_on_gui_input.bind(node))
			connected_nodes.append(node)
			
	for child in node.get_children(true):
		_connect_inputs(child)

func _on_gui_input(event: InputEvent, node: Control):
	# 1. 마우스 왼쪽 단일/더블 클릭 감지
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			# 첫 번째 싱글 클릭이 스크립트를 '읽기 전용'으로 잠가버리는 찰나를 완벽히 우회하기 위해
			# 더블클릭 감지 시 강제로 에디터 열기 API를 직접 다이렉트로 때립니다!
			_trigger_double_click_open()
			return
			
		_trigger_inspector_update(node)
		return
		
	# 2. 키보드 방향키 위/아래 감지
	if event is InputEventKey and event.pressed:
		if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
			if node is Tree:
				_handle_tree_navigation(event, node)
			elif node is ItemList:
				_trigger_inspector_update(node)

func _handle_tree_navigation(event: InputEventKey, tree: Tree):
	var selected = tree.get_selected()
	if not selected:
		return

	# 현재 선택된 항목을 기준으로 다음/이전 '보이는' 항목을 찾습니다. (폴더 열림/닫힘 완벽 호환)
	var target: TreeItem = null
	if event.is_action_pressed("ui_up", true):
		target = selected.get_prev_visible()
	elif event.is_action_pressed("ui_down", true):
		target = selected.get_next_visible()

	if target:
		# 핵심 1: 다중 선택이 누적되는 것을 막기 위해 기존 선택을 싹 지우고 새 타겟만 강제 선택합니다.
		tree.deselect_all()
		target.select(0)
		tree.scroll_to_item(target)
		
		# 핵심 2: 고도 엔진이 기본 방향키 동작(가짜 커서 이동)을 하지 못하도록 이벤트를 소멸시킵니다.
		tree.accept_event()
		
		# 핵심 3: 인스펙터 갱신을 트리거합니다.
		_trigger_inspector_update(tree)


func _trigger_inspector_update(node: Control):
	call_deferred("_update_inspector_from_paths", node)

func _trigger_double_click_open():
	call_deferred("_handle_double_click_execution")

func _handle_double_click_execution():
	await get_tree().process_frame
	var paths = EditorInterface.get_selected_paths()
	if paths.size() != 1: return
	var path = paths[0]
	if path.is_empty() or DirAccess.dir_exists_absolute(path): return
	
	var res = ResourceLoader.load(path)
	if res:
		if res is Script:
			# 스크립트인 경우 특수하게 edit_script를 호출하여 inspector_only 모드 락을 강제로 박살냅니다!
			EditorInterface.edit_script(res, -1, 0, true)
		else:
			EditorInterface.edit_resource(res)

func _update_inspector_from_paths(node: Control):
	# 파일 경로가 완전히 선택될 때까지 1프레임 대기합니다.
	await get_tree().process_frame
	
	var paths = EditorInterface.get_selected_paths()
	if paths.size() != 1: return
	
	var path = paths[0]
	if path.is_empty() or DirAccess.dir_exists_absolute(path): return
	
	# 무거운 파일은 로드하지 않습니다.
	var ext = path.get_extension().to_lower()
	if ext in []: return
	
	var res = ResourceLoader.load(path)
	if res:
		# inspector_only 매개변수를 true로 설정하면, 고도 엔진이 스크립트를 즉시 외부 에디터로
		# 강제 오픈해버리거나 메인 화면을 제멋대로 이동시키는 네이티브 연결 동작(Edit)을 완벽히 차단하고
		# 이름 그대로 "우측 인스펙터 패널에만 정보 표시" 동작을 깔끔하게 수행합니다.
		EditorInterface.inspect_object(res, "", true)
		
		# 파일 확장자에 따라 에디터 메인 화면(워크스페이스)을 자동으로 전환합니다.
		# 주의: Godot 4 API에는 get_editor_main_screen()이 없으므로 직접 추적한 last_workspace 사용
		
		if ext in ["tscn", "scn", "tres", "res", "png", "jpg", "wav", "ogg"]:
			# 씬이나 리소스 선택 시, 이전에 작업하던 2D 또는 3D 뷰로 복귀
			EditorInterface.set_main_screen_editor(last_workspace)
		elif ext in ["gd", "cs"]:
			# 외부 에디터 설정(VSCode 등) 사용 여부 체크
			var use_external = EditorInterface.get_editor_settings().get_setting("text_editor/external/use_external_editor")
			
			if use_external:
				# 외부 에디터를 쓴다면, 의미 없는 내부 Script 탭으로 가지 않고 작업하던 2D/3D 뷰를 그대로 유지!
				EditorInterface.set_main_screen_editor(last_workspace)
				# 스크립트를 실제로 열어주기를 원하시는 뉘앙스라면 주석을 해제하세요:
				# EditorInterface.edit_resource(res) 
			else:
				# 내부 에디터 사용 시에만 Script 뷰로 자동 전환
				EditorInterface.set_main_screen_editor("Script")
				# 단일 클릭/화살표 선택 시마다 내부 스크립트 창의 내용물(에디터 뷰)도 즉시 갱신합니다!
				if res is Script:
					EditorInterface.edit_script(res, -1, 0, false) # 포커스는 계속 파일시스템에 남아있도록 false 전달
		
		# 인스펙터가 정보를 띄우자마자 파일 시스템으로 즉시 포커스를 돌려놓습니다.
		if is_instance_valid(node):
			node.call_deferred("grab_focus")
