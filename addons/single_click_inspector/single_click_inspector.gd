@tool
extends EditorPlugin

var connected_nodes: Array[Control] = []

func _enter_tree():
	var fs_dock = EditorInterface.get_file_system_dock()
	_connect_inputs(fs_dock)

func _exit_tree():
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
	# 1. 마우스 왼쪽 단일 클릭 감지
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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

func _update_inspector_from_paths(node: Control):
	# 파일 경로가 완전히 선택될 때까지 1프레임 대기합니다.
	await get_tree().process_frame
	
	var paths = EditorInterface.get_selected_paths()
	if paths.size() != 1: return
	
	var path = paths[0]
	if path.is_empty() or DirAccess.dir_exists_absolute(path): return
	
	# 무거운 파일은 로드하지 않습니다.
	var ext = path.get_extension().to_lower()
	if ext in ["tscn", "scn", "glb", "gltf", "obj", "fbx"]: return
	
	var res = ResourceLoader.load(path)
	if res:
		# 개발자님의 아이디어: 포커스를 뺏기기 전에 미리 기억해 두었다가
		EditorInterface.inspect_object(res)
		
		# 인스펙터가 정보를 띄우자마자 파일 시스템으로 즉시 포커스를 돌려놓습니다.
		if is_instance_valid(node):
			node.call_deferred("grab_focus")
