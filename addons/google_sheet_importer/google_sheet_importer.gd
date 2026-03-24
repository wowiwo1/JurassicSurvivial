@tool
extends EditorPlugin

# --- 설정값 입력 ---
const CREDENTIALS_PATH = "res://credentials/credentials.json"
const SHEET_ID = "1W9w7dGUs-dBSsdPYmA-Oj8_EUYPlqqhzXOjyBOg8KUo"
const START_CELL = "A6:ZZ" # A6부터 데이터가 존재하는 끝까지 자동으로 잘려서 옵니다.
const SAVE_DIR = "res://assets/game_table"
const SAVE_PATH = "res://assets/game_table/game_table.json"

const SCRIPT_DIR = "res://assets/game_table/scripts"
const DATA_DIR = "res://assets/game_table/data"
# -------------------

var http_auth: HTTPRequest
var http_meta: HTTPRequest
var http_data: HTTPRequest

var access_token: String = ""
var sheet_titles: Array[String] = []

func _enter_tree():
	add_tool_menu_item("🚀 Request GoogleSheet", _start_import_process)
	
	http_auth = HTTPRequest.new()
	http_meta = HTTPRequest.new()
	http_data = HTTPRequest.new()
	
	add_child(http_auth)
	add_child(http_meta)
	add_child(http_data)
	
	http_auth.request_completed.connect(_on_auth_completed)
	http_meta.request_completed.connect(_on_meta_completed)
	http_data.request_completed.connect(_on_data_completed)

func _exit_tree():
	remove_tool_menu_item("Request GoogleSheet")
	if http_auth: http_auth.queue_free()
	if http_meta: http_meta.queue_free()
	if http_data: http_data.queue_free()

# ---------------------------------------------------------
# 1. 프로세스 시작 (JWT 인증)
# ---------------------------------------------------------
func _start_import_process():
	print("🚀 구글 시트 임포트 시작...")
	var cred_file = FileAccess.open(CREDENTIALS_PATH, FileAccess.READ)
	if not cred_file:
		push_error("Credentials 파일을 찾을 수 없습니다: " + CREDENTIALS_PATH)
		return
		
	var cred_json = JSON.parse_string(cred_file.get_as_text())
	var jwt = _generate_jwt(cred_json["client_email"], cred_json["private_key"])
	
	var url = "https://oauth2.googleapis.com/token"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" + jwt
	
	http_auth.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_auth_completed(result, response_code, headers, body):
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		access_token = response["access_token"]
		_request_sheet_meta()
	else:
		push_error("인증 실패! Response Code: " + str(response_code))

# ---------------------------------------------------------
# 2. 메타데이터 요청 (모든 시트 이름 가져오기)
# ---------------------------------------------------------
func _request_sheet_meta():
	print("📋 시트 탭 목록 가져오는 중...")
	var url = "https://sheets.googleapis.com/v4/spreadsheets/%s" % SHEET_ID
	var headers = ["Authorization: Bearer " + access_token]
	http_meta.request(url, headers, HTTPClient.METHOD_GET)

func _on_meta_completed(result, response_code, headers, body):
	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		sheet_titles.clear()
		for sheet in data["sheets"]:
			sheet_titles.append(sheet["properties"]["title"])
		print("✅ 발견된 시트: ", sheet_titles)
		_request_batch_data()
	else:
		push_error("시트 메타데이터 가져오기 실패! " + str(response_code))

# ---------------------------------------------------------
# 3. 데이터 일괄 요청 (모든 시트의 A6:ZZ 가져오기)
# ---------------------------------------------------------
func _request_batch_data():
	print("📥 각 시트별 데이터 추출 중...")
	var ranges_query = ""
	for title in sheet_titles:
		if ranges_query != "": ranges_query += "&"
		var target_range = "%s!%s" % [title, START_CELL]
		ranges_query += "ranges=" + target_range.uri_encode()
		
	var url = "https://sheets.googleapis.com/v4/spreadsheets/%s/values:batchGet?%s" % [SHEET_ID, ranges_query]
	var headers = ["Authorization: Bearer " + access_token, "Accept: application/json"]
	http_data.request(url, headers, HTTPClient.METHOD_GET)

func _on_data_completed(result, response_code, headers, body):
	if response_code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		_save_to_json(data)
	else:
		push_error("데이터 가져오기 실패! " + str(response_code))
		print(body.get_string_from_utf8())

# ---------------------------------------------------------
# 4. JSON 포맷팅 및 파일 저장
# ---------------------------------------------------------
func _save_to_json(batch_data: Dictionary):
	var final_dict = {}
	var value_ranges = batch_data.get("valueRanges", [])
	
	for i in range(sheet_titles.size()):
		var title = sheet_titles[i]
		var raw_values = []
		if i < value_ranges.size() and value_ranges[i].has("values"):
			raw_values = value_ranges[i]["values"]
			
		# 여기서 불필요한 빈칸과 코멘트를 걸러냅니다!
		var filtered_values = _filter_sheet_data(raw_values)
		
		# 필터링 결과 데이터가 아예 없다면 해당 시트는 JSON에서 제외
		if not filtered_values.is_empty():
			final_dict[title] = filtered_values

	var dir = DirAccess.open("res://")
	if not dir.dir_exists(SAVE_DIR):
		dir.make_dir_recursive(SAVE_DIR)

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(final_dict, "\t"))
		file.close()
		print("🎉 저장 완료! 불필요한 데이터가 깔끔하게 제거되었습니다. 경로: ", SAVE_PATH)
	else:
		push_error("파일 저장 실패: " + SAVE_PATH)
	
	_generate_resources_from_dict(final_dict)

# =========================================================
# 헬퍼 함수: JWT 생성
# =========================================================
func _generate_jwt(client_email: String, private_key_string: String) -> String:
	var header = {"alg": "RS256", "typ": "JWT"}
	var now = Time.get_unix_time_from_system()
	var claim = {
		"iss": client_email,
		"scope": "https://www.googleapis.com/auth/spreadsheets.readonly",
		"aud": "https://oauth2.googleapis.com/token",
		"iat": now,
		"exp": now + 3600
	}
	
	var head_b64 = _base64_url_encode(JSON.stringify(header).to_utf8_buffer())
	var claim_b64 = _base64_url_encode(JSON.stringify(claim).to_utf8_buffer())
	var signature_input = head_b64 + "." + claim_b64
	
	var crypto = Crypto.new()
	var key = CryptoKey.new()
	var err = key.load_from_string(private_key_string)
	if err != OK: return ""
		
	var signature = crypto.sign(HashingContext.HASH_SHA256, signature_input.sha256_buffer(), key)
	return signature_input + "." + _base64_url_encode(signature)

func _base64_url_encode(data: PackedByteArray) -> String:
	var b64 = Marshalls.raw_to_base64(data)
	return b64.replace("+", "-").replace("/", "_").replace("=", "")
	
# =========================================================
# 헬퍼 함수: 데이터 필터링 (빈 행/열을 만나면 즉시 읽기 중단)
# =========================================================
func _filter_sheet_data(raw_values: Array) -> Array:
	if raw_values.is_empty():
		return []

	var headers = raw_values[0]
	var valid_col_indices = []

	# 1. 유효한 컬럼(열) 찾기
	for i in range(headers.size()):
		var header_text = str(headers[i]).strip_edges()
		
		# 헤더가 비어있으면 그 이후 열은 전부 무시 (반복문 완전 종료)
		if header_text == "":
			break 
			
		# '#'으로 시작하는 열은 이 열만 무시 (메모용 열)
		if not header_text.begins_with("#"):
			valid_col_indices.append(i)

	if valid_col_indices.is_empty():
		return []

	var filtered_data = []

	# 2. 필터링된 헤더 추가
	var filtered_headers = []
	for i in valid_col_indices:
		filtered_headers.append(str(headers[i]).strip_edges())
	filtered_data.append(filtered_headers)

	# 3. 데이터 행(Row 1 ~ 끝) 필터링
	for row_idx in range(1, raw_values.size()):
		var row = raw_values[row_idx]
		var first_cell = ""
		
		if row.size() > 0:
			first_cell = str(row[0]).strip_edges()
			
		# 첫 번째 셀(ID)이 비어있으면 그 아래 행은 전부 무시 (반복문 완전 종료)
		if first_cell == "":
			break
			
		# '#'으로 시작하는 행은 이 행만 무시 (데이터 임시 제외용)
		if first_cell.begins_with("#"):
			continue
			
		# 유효한 열의 데이터만 조립
		var filtered_row = []
		for col_idx in valid_col_indices:
			if col_idx < row.size():
				filtered_row.append(str(row[col_idx]))
			else:
				filtered_row.append("") # API가 자른 빈칸 복구
				
		filtered_data.append(filtered_row)

	return filtered_data
	
	
func _generate_resources_from_dict(table_dict: Dictionary):
	print("⚙️ 리소스(.tres) 베이킹을 시작합니다...")
	
	# 1. 폴더 확인 및 생성 (기존 파일은 덮어쓰기 방식으로 유지하여 Git UUID 변경 방지)
	var dir = DirAccess.open("res://")
	for target_dir in [SCRIPT_DIR, DATA_DIR]:
		if not dir.dir_exists(target_dir):
			dir.make_dir_recursive(target_dir)
			
	var valid_script_files = ["table_container.gd"]
	var valid_data_files = []

	# 2. 공통 컨테이너 스크립트 생성 (딕셔너리 형태로 데이터를 담을 껍데기)
	var container_script_path = SCRIPT_DIR + "/table_container.gd"
	if not FileAccess.file_exists(container_script_path):
		var c_file = FileAccess.open(container_script_path, FileAccess.WRITE)
		c_file.store_string("extends Resource\nclass_name TableContainer\n\n@export var records: Dictionary = {}\n")
		c_file.close()
		
	# 캐시를 무시하고 스크립트 로드
	var container_script = ResourceLoader.load(container_script_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	# 3. 각 시트(Card, Map, Recipe 등) 순회
	for sheet_name in table_dict.keys():
		var rows = table_dict[sheet_name]
		if rows.size() < 2: continue # 헤더 외에 데이터가 없으면 건너뜀
		
		var raw_headers = rows[0]
		var parsed_headers = []
		
		# --- A. 동적 스크립트(.gd) 코드 작성 ---
		var class_name_str = sheet_name.to_pascal_case() + "Data"
		var script_code = "@tool\nextends Resource\nclass_name %s\n\n" % class_name_str
		
		for h in raw_headers:
			var h_str = str(h).strip_edges()
			var var_name = h_str
			var var_type = "string"
			var gd_type = "String"
			
			# "Name{string}" 형태 파싱
			if "{" in h_str and "}" in h_str:
				var parts = h_str.split("{")
				var_name = parts[0].strip_edges()
				var_type = parts[1].replace("}", "").to_lower()
				
			# 전역 클래스 이름 충돌을 피하기 위해 snake_case로 강제 변환 (예: Time -> time)
			var_name = var_name.to_snake_case()
				
			# GDScript 자료형 매핑
			if var_type == "int": gd_type = "int"
			elif var_type == "float": gd_type = "float"
			
			parsed_headers.append({"name": var_name, "type": var_type})
			script_code += "@export var %s: %s\n" % [var_name, gd_type]
			
		# 스크립트 파일명 관리 (.gd)
		var s_file_name = "%s_data.gd" % sheet_name.to_snake_case()
		valid_script_files.append(s_file_name)
		var script_path = SCRIPT_DIR + "/" + s_file_name
		
		# 내용이 달라졌을 때만 덮어쓰기 (Git Modified 최소화)
		var is_changed = true
		if FileAccess.file_exists(script_path):
			if FileAccess.get_file_as_string(script_path) == script_code:
				is_changed = false
				
		if is_changed:
			var s_file = FileAccess.open(script_path, FileAccess.WRITE)
			s_file.store_string(script_code)
			s_file.close()
		
		# 막 생성/수정된 스크립트를 캐시 무시하고 강제로 메모리에 로드
		var row_script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		
		# --- B. 리소스(.tres) 인스턴스화 및 데이터 채우기 ---
		var table_resource = container_script.new()
		
		for i in range(1, rows.size()):
			var row_data = rows[i]
			var row_instance = row_script.new()
			var primary_key = null
			
			for j in range(parsed_headers.size()):
				if j >= row_data.size(): break
				var ph = parsed_headers[j]
				var val_str = str(row_data[j]).strip_edges()
				var val
				
				# 자료형에 맞게 캐스팅 (빈칸이면 0 또는 0.0 처리)
				if ph.type == "int": 
					val = val_str.to_int() if val_str != "" else 0
				elif ph.type == "float": 
					val = val_str.to_float() if val_str != "" else 0.0
				else: 
					val = val_str
				
				# 인스턴스에 값 할당
				row_instance.set(ph.name, val)
				
				# 첫 번째 컬럼(ID)을 딕셔너리의 키로 사용
				if j == 0: 
					primary_key = val
					
			if primary_key != null:
				table_resource.records[primary_key] = row_instance
				
		# --- C. 최종 .tres 파일 저장 ---
		var r_file_name = "%s_table.tres" % sheet_name.to_snake_case()
		valid_data_files.append(r_file_name)
		var res_path = DATA_DIR + "/" + r_file_name
		
		# Godot 4의 ResourceSaver는 파일이 존재할 경우 기존 파일의 UID를 유지하면서 속성만 업데이트합니다.
		ResourceSaver.save(table_resource, res_path)
		print("✅ 리소스 구워짐: ", res_path)

	# 4. 고스트 파일(구글 시트에서 삭제된 시트의 이전 산출물) 청소
	var dict_dirs = { SCRIPT_DIR: valid_script_files, DATA_DIR: valid_data_files }
	for d_path in dict_dirs.keys():
		var valid_list = dict_dirs[d_path]
		var d = DirAccess.open(d_path)
		if d:
			for f in d.get_files():
				var base_name = f.replace(".import", "").replace(".uid", "")
				if not valid_list.has(base_name) and not valid_list.has(f):
					d.remove(f)

	# 에디터 파일 시스템 새로고침 (저장된 파일을 인스펙터에 바로 띄우기 위함)
	get_editor_interface().get_resource_filesystem().scan()
	print("🎉 모든 데이터 임포트 작업이 완료되었습니다!")
