extends Control

@onready var tree: Tree = $Tree

var table_data = [
	["ID", "Name", "Type", "Weight", "Description"],
	["10001", "얕은 바다", "지형", "0", "해안 가까이 펼쳐진 얕은 바다입니다."],
	["3006", "해초 채집", "액션", "0", "해초와 해초 재료를 뜯어냅니다."],
	["40016", "해초", "자원", "0.5", "식용이나 재료로 쓰이는 해초입니다."],
	["10010", "침엽수림", "지형", "0", "도끼가 있어야 제대로 벌목할 수 있는 침엽수 숲입니다."]
]

func _ready():
	setup_tree()
	populate_tree()
	auto_fit_size() # 데이터가 다 채워진 후 너비 조절 실행
	sync_edit_font() # 편집창 폰트 크기 동기화 함수 호출
	
	# 수정이 완료되었을 때 실행될 시그널 연결
	tree.item_edited.connect(_on_tree_item_edited)
	tree.item_activated.connect(_on_tree_item_activated)

func setup_tree():
	var column_count = table_data[0].size()
	tree.columns = column_count 
	tree.column_titles_visible = true
	
	for i in range(column_count):
		tree.set_column_title(i, table_data[0][i])

func populate_tree():
	var root = tree.create_item()
	tree.hide_root = true

	for row_idx in range(1, table_data.size()):
		var row_data = table_data[row_idx]
		var item = tree.create_item(root)
		# 이 TreeItem이 원본 배열의 몇 번째 행인지 메타데이터로 기억해둡니다.
		item.set_metadata(0, row_idx)

		for col_idx in range(row_data.size()):
			item.set_text(col_idx, str(row_data[col_idx]))

# 새로 추가된 함수: 더블 클릭 시 호출됨
func _on_tree_item_activated():
	var item = tree.get_selected()
	var col = tree.get_selected_column()

	if item:
		# 더블 클릭한 순간에만 해당 셀을 수정 가능 상태로 켭니다.
		item.set_editable(col, true)

		# 엔진에 해당 셀의 편집창을 즉시 띄우도록 명령합니다.
		tree.edit_selected()

# 셀 수정이 완료(엔터키 또는 포커스 잃음)되었을 때 호출되는 함수
func _on_tree_item_edited():
	var edited_item = tree.get_edited()
	var edited_column = tree.get_edited_column()
	var new_text = edited_item.get_text(edited_column)
	var row_idx = edited_item.get_metadata(0)
	var col_name = table_data[0][edited_column] 
	
	print("✅ 수정 완료! [행: %d] %s -> %s" % [row_idx, col_name, new_text])
	
	# 원본 배열 업데이트
	table_data[row_idx][edited_column] = new_text
	
	# 💡 핵심: 편집이 끝났으므로 다시 읽기 전용으로 잠가서 싱글 클릭 방지!
	edited_item.set_editable(edited_column, false)
	
	auto_fit_size()

func sync_edit_font():
	# 1. 현재 Tree가 사용 중인 폰트와 사이즈를 가져옵니다.
	var font = tree.get_theme_font("font")
	var font_size = tree.get_theme_font_size("font_size")
	
	# 2. Tree 노드에 고유한 Theme 리소스가 없다면 새로 생성해 줍니다.
	if tree.theme == null:
		tree.theme = Theme.new()
		
	# 3. 내부에서 팝업되는 LineEdit(편집창)의 폰트와 크기를 Tree와 동일하게 강제 세팅합니다.
	tree.theme.set_font_size("font_size", "LineEdit", font_size)
	tree.theme.set_font("font", "LineEdit", font)
	
	var font_color = tree.get_theme_color("font_color")
	tree.theme.set_color("font_color", "LineEdit", font_color)
	
# --- 새로 추가된 컬럼 자동 맞춤 함수 ---
func auto_fit_size():
	var font = tree.get_theme_font("font")
	var font_size = tree.get_theme_font_size("font_size")
	
	# -----------------------------------
	# 1. 가로(Width) 총합 계산
	# -----------------------------------
	var padding_x = 24 
	var column_count = table_data[0].size() 
	var total_width = 10 

	for col_idx in range(column_count):
		var max_width = 0

		for row_data in table_data:
			var text = str(row_data[col_idx])
			var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			
			if text_width > max_width:
				max_width = text_width

		var final_col_width = max_width + padding_x
		tree.set_column_custom_minimum_width(col_idx, final_col_width)
		tree.set_column_expand(col_idx, false) 
		total_width += final_col_width

	# -----------------------------------
	# 2. 세로(Height) 총합 계산
	# -----------------------------------
	# 폰트의 실제 픽셀 높이를 가져옵니다.
	var font_height = font.get_height(font_size)
	
	# Tree 노드의 테마에 설정된 행 사이의 세로 여백(v_separation)을 가져옵니다.
	var v_sep = tree.get_theme_constant("v_separation")
	
	# 1줄(Row)당 차지하는 대략적인 높이 (내부 여백을 위해 6픽셀 정도 추가)
	var row_height = font_height + v_sep + 6
	
	# 화면에 보이는 전체 행의 개수 (헤더 1줄 + 실제 데이터 행들)
	# 현재 table_data의 길이와 화면에 그려지는 줄 수가 동일합니다.
	var visible_row_count = table_data.size() 
	
	# 헤더는 일반 행보다 테두리(StyleBox) 여백이 조금 더 크므로 약간의 보정값을 더합니다.
	var header_padding = 20
	
	var total_height = (row_height * visible_row_count) + header_padding

	# -----------------------------------
	# 3. 최종 크기 적용 (가로, 세로)
	# -----------------------------------
	tree.custom_minimum_size = Vector2(total_width, total_height)
	tree.size = Vector2(total_width, total_height)
