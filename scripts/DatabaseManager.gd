static func load_json_data(file_name: String) -> Variant:
	# 1. Try user://data/ (The downloaded path)
	var user_path = "user://data/" + file_name
	if FileAccess.file_exists(user_path):
		var file = FileAccess.open(user_path, FileAccess.READ)
		var content = JSON.parse_string(file.get_as_text())
		file.close()
		return content

	# 2. Fallback to res://data/ (The packaged path)
	var res_path = "res://data/" + file_name
	if FileAccess.file_exists(res_path):
		var file = FileAccess.open(res_path, FileAccess.READ)
		var content = JSON.parse_string(file.get_as_text())
		file.close()
		return content
		
	push_error("JSON file missing in both user:// and res://: " + file_name)
	return null
