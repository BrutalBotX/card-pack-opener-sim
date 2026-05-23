extends Control

@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var action_btn: Button = $MarginContainer/VBoxContainer/ActionBtn

const RELEASE_URL = "https://github.com/flibustier/pokemon-tcg-pocket-database/releases/latest/download/release.zip"
const TEMP_ZIP_PATH = "user://temp_release.zip"

const USER_JSON_DIR = "user://data/json"
const USER_ASSETS_DIR = "user://assets/cards" 
const MAIN_HUB_PATH = "res://scenes/main_hub.tscn"

var http_request: HTTPRequest
var is_downloading: bool = false
var is_extracting: bool = false
var extraction_thread: Thread

func _ready() -> void:
	# 1. Startup Check: Bypass downloader if core dataset and folders exist
	if FileAccess.file_exists(USER_JSON_DIR + "/cards.json") and DirAccess.dir_exists_absolute(USER_ASSETS_DIR):
		var dir = DirAccess.open(USER_ASSETS_DIR)
		if dir and (dir.get_files().size() > 0 or dir.get_directories().size() > 0):
			print("Assets found locally. Bypassing installer and launching hub...")
			
			# FIX: Use call_deferred to safely change scenes after _ready() finishes
			get_tree().call_deferred("change_scene_to_file", MAIN_HUB_PATH)
			return

	# 2. Fresh configuration setup if datasets are missing
	DirAccess.make_dir_recursive_absolute(USER_JSON_DIR)
	DirAccess.make_dir_recursive_absolute(USER_ASSETS_DIR)
	
	http_request = HTTPRequest.new()
	http_request.use_threads = true 
	add_child(http_request)
	
	http_request.request_completed.connect(_on_http_request_completed)
	action_btn.pressed.connect(_on_action_btn_pressed)

func _process(_delta: float) -> void:
	if is_downloading and not is_extracting:
		var downloaded = http_request.get_downloaded_bytes()
		var total = http_request.get_body_size()
		
		if total > 0:
			progress_bar.max_value = total
			progress_bar.value = downloaded
			var mb_down = snapped(float(downloaded) / 1048576.0, 0.1)
			var mb_total = snapped(float(total) / 1048576.0, 0.1)
			status_label.text = "Downloading Database: " + str(mb_down) + "MB / " + str(mb_total) + "MB"

func _on_action_btn_pressed() -> void:
	if is_downloading: return
	
	is_downloading = true
	action_btn.disabled = true
	progress_bar.value = 0
	
	http_request.download_file = TEMP_ZIP_PATH
	var error = http_request.request(RELEASE_URL)
	if error != OK:
		status_label.text = "CRITICAL: Could not connect to GitHub."
		reset_ui()

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code > 299:
		status_label.text = "Download Failed! HTTP Code: " + str(response_code)
		reset_ui()
		return
		
	is_extracting = true
	status_label.text = "Download Complete. Extracting at High Speed..."
	progress_bar.value = 0
	
	extraction_thread = Thread.new()
	extraction_thread.start(_extract_in_background)

# --- BACKGROUND THREAD (NO SCENE TREE / UI MANIPULATION) ---
func _extract_in_background() -> void:
	var zip = ZIPReader.new()
	var err = zip.open(TEMP_ZIP_PATH)
	
	if err != OK:
		call_deferred("_on_extraction_error", "CRITICAL: Downloaded ZIP file is corrupted.")
		return
		
	var files = zip.get_files()
	call_deferred("_set_progress_max", files.size())
	
	var processed_count = 0
	
	for file_path in files:
		processed_count += 1
		
		if file_path.ends_with("/"):
			continue
			
		if processed_count % 50 == 0:
			call_deferred("_update_extraction_ui", processed_count, file_path.get_file())
			
		var content: PackedByteArray = zip.read_file(file_path)
		
		var is_target_json = (
			file_path == "dist/cards.json" or 
			file_path == "dist/pullRates.json" or 
			file_path == "dist/rarities.json" or 
			file_path == "dist/sets.json"
		)
		
		if is_target_json:
			var save_path = USER_JSON_DIR + "/" + file_path.get_file()
			_save_bytes_to_disk(save_path, content)
			
		elif file_path.begins_with("dist/images/"):
			# Isolate relative path structure from zip archive
			var relative_path = file_path.trim_prefix("dist/images/")
			var save_path = USER_ASSETS_DIR + "/" + relative_path
			
			# Extract base directory and build matching folders in user:// directory
			var sub_dir = save_path.get_base_dir()
			DirAccess.make_dir_recursive_absolute(sub_dir)
			
			_save_bytes_to_disk(save_path, content)
			
	zip.close()
	call_deferred("_on_extraction_finished")

func _save_bytes_to_disk(path: String, data: PackedByteArray) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(data)
		file.close()

# --- MAIN THREAD UI HANDLERS ---
func _set_progress_max(max_val: int) -> void:
	progress_bar.max_value = max_val

func _update_extraction_ui(count: int, filename: String) -> void:
	progress_bar.value = count
	status_label.text = "Extracting: " + filename

func _on_extraction_error(msg: String) -> void:
	if extraction_thread and extraction_thread.is_alive():
		extraction_thread.wait_to_finish()
	status_label.text = msg
	clean_up_temp_zip()
	reset_ui()

func _on_extraction_finished() -> void:
	if extraction_thread and extraction_thread.is_alive():
		extraction_thread.wait_to_finish()
	clean_up_temp_zip()
	
	status_label.text = "All assets successfully installed!"
	progress_bar.value = progress_bar.max_value
	
	action_btn.text = "Enter Game"
	action_btn.disabled = false
	action_btn.pressed.disconnect(_on_action_btn_pressed)
	action_btn.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_HUB_PATH))

func clean_up_temp_zip() -> void:
	if FileAccess.file_exists(TEMP_ZIP_PATH):
		DirAccess.remove_absolute(TEMP_ZIP_PATH)

func reset_ui() -> void:
	is_downloading = false
	is_extracting = false
	action_btn.disabled = false
	action_btn.text = "Retry Download"

func _exit_tree() -> void:
	if extraction_thread and extraction_thread.is_alive():
		extraction_thread.wait_to_finish()
