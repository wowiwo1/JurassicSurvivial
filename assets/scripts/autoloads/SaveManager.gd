extends Node

# 필드 위에 뿌려진 모든 카드의 X, Y 좌표와 스택/내구도를 저장/로드
const SAVE_PATH = "user://game_save.json"

func save_game(cards: Array):
	var save_data = []
	for card in cards:
		if card.has_method("get_save_data"):
			save_data.append(card.get_save_data())
			
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))

func load_game() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	var parsed_data = JSON.parse_string(json_string)
	
	if typeof(parsed_data) == TYPE_ARRAY:
		return parsed_data
	return []
