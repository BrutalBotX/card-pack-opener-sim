extends Control

@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var action_btn: Button = $MarginContainer/VBoxContainer/ActionBtn

const RELEASE_URL = "https://github.com/flibustier/pokemon-tcg-pocket-database/releases/latest/download/release.zip"
const TEMP_ZIP_PATH = "user://temp_release.zip"

# FIX: Pointed directly to the root folders so subfolders extract correctly
const USER_JSON_DIR = "user://data"
const USER_ASSETS_DIR = "user://assets" 
const MAIN_HUB_PATH = "res://scenes/main_hub.tscn"

# BULLETPROOF CHECK: A tiny file we write ONLY when extraction hits 100%
const SETUP_FLAG = "user://setup_complete.flag"

enum State { READY, DOWNLOADING, EXTRACTING, FINISHED }
var current_state: State = State.READY

var http_request: HTTPRequest
var extraction_thread: Thread
var glow_tween: Tween

func _ready() -> void:
	# 1. The Bulletproof Startup Check
	if FileAccess.file_exists(SETUP_FLAG):
		print("Setup Flag found. Bypassing downloader...")
		get_tree().call_deferred("change_scene_to_file", MAIN_HUB_PATH)
		return

	# 2. Setup Base Directories
	DirAccess.make_dir_recursive_absolute(USER_JSON_DIR)
	DirAccess.make_dir_recursive_absolute(USER_ASSETS_DIR)
	
	http_request = HTTPRequest.new()
	http_request.use_threads = true 
	add_child(http_request)
	
	http_request.request_completed.connect(_on_http_request_completed)
	action_btn.pressed.connect(_on_action_btn_pressed)
	
	_apply_aaa_visual_styling()

func _process(_delta: float) -> void:
	if current_state == State.DOWNLOADING:
		var downloaded = http_request.get_downloaded_bytes()
		var total = http_request.get_body_size()
		
		if total > 0:
			progress_bar.max_value = total
			progress_bar.value = downloaded
			var mb_down = snapped(float(downloaded) / 1048576.0, 0.1)
			var mb_total = snapped(float(total) / 1048576.0, 0.1)
			status_label.text = "Downloading Database: " + str(mb_down) + "MB / " + str(mb_total) + "MB"

func _on_action_btn_pressed() -> void:
	# STATE 1: Start the Download
	if current_state == State.READY:
		current_state = State.DOWNLOADING
		action_btn.disabled = true
		action_btn.text = "Downloading..."
		progress_bar.value = 0
		
		http_request.download_file = TEMP_ZIP_PATH
		var error = http_request.request(RELEASE_URL)
		if error != OK:
			_on_extraction_error("CRITICAL: Could not connect to GitHub.")
			
	# STATE 2: Launch the Game 
	elif current_state == State.FINISHED:
		get_tree().change_scene_to_file(MAIN_HUB_PATH)

func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code > 299:
		_on_extraction_error("Download Failed! HTTP Code: " + str(response_code))
		return
		
	current_state = State.EXTRACTING
	status_label.text = "Download Complete. Extracting assets..."
	progress_bar.value = 0
	
	extraction_thread = Thread.new()
	extraction_thread.start(_extract_in_background)

# --- BACKGROUND THREAD ---
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
		
		# Skip directories
		if file_path.ends_with("/"):
			continue
			
		# Exclude redundant 'cards-by-set' folder 
		if "cards-by-set" in file_path:
			continue
			
		# Exclude international set logos (Keep only en_US)
		if "LOGO_expansion_" in file_path and not "_en_US.webp" in file_path:
			continue
			
		if processed_count % 50 == 0:
			call_deferred("_update_extraction_ui", processed_count, file_path.get_file())
			
		var content: PackedByteArray = zip.read_file(file_path)
		
		# Route JSONs directly to user://data/
		var is_target_json = (
			file_path == "dist/cards.json" or 
			file_path == "dist/pullRates.json" or 
			file_path == "dist/rarities.json" or 
			file_path == "dist/sets.json"
		)
		
		if is_target_json:
			var save_path = USER_JSON_DIR + "/" + file_path.get_file()
			_save_bytes_to_disk(save_path, content)
			
		# Route Images directly to user://assets/ (preserving cards/, packs/, sets/ structure)
		elif file_path.begins_with("dist/images/"):
			var relative_path = file_path.trim_prefix("dist/images/")
			var save_path = USER_ASSETS_DIR + "/" + relative_path
			
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
	status_label.text = "Unpacking: " + filename

func _on_extraction_error(msg: String) -> void:
	if extraction_thread and extraction_thread.is_alive():
		extraction_thread.wait_to_finish()
	status_label.text = msg
	_clean_up_temp_zip()
	current_state = State.READY
	action_btn.disabled = false
	action_btn.text = "Retry Download"

func _on_extraction_finished() -> void:
	if extraction_thread and extraction_thread.is_alive():
		extraction_thread.wait_to_finish()
	_clean_up_temp_zip()
	
	# WRITE THE COMPLETION FLAG: This guarantees we never double-download!
	var flag_file = FileAccess.open(SETUP_FLAG, FileAccess.WRITE)
	flag_file.store_string("Setup Complete.")
	flag_file.close()
	
	current_state = State.FINISHED
	status_label.text = "All assets successfully installed!"
	progress_bar.value = progress_bar.max_value
	
	action_btn.text = "ENTER GAME"
	action_btn.disabled = false
	_start_button_pulse()

func _clean_up_temp_zip() -> void:
	if FileAccess.file_exists(TEMP_ZIP_PATH):
		DirAccess.remove_absolute(TEMP_ZIP_PATH)

# --- VISUAL ENHANCEMENTS ---
func _apply_aaa_visual_styling() -> void:
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	bg_style.corner_radius_top_left = 12
	bg_style.corner_radius_top_right = 12
	bg_style.corner_radius_bottom_left = 12
	bg_style.corner_radius_bottom_right = 12
	bg_style.expand_margin_left = 2
	bg_style.expand_margin_right = 2
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.7, 0.9, 1.0) 
	fill_style.corner_radius_top_left = 12
	fill_style.corner_radius_top_right = 12
	fill_style.corner_radius_bottom_left = 12
	fill_style.corner_radius_bottom_right = 12
	
	progress_bar.add_theme_stylebox_override("background", bg_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	progress_bar.custom_minimum_size.y = 24
	progress_bar.show_percentage = false

func _start_button_pulse() -> void:
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(action_btn, "modulate", Color(1.2, 1.2, 1.2, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(action_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func _exit_tree() -> void:
	if extraction_thread and extraction_thread.is_alive():
		extraction_thread.wait_to_finish()
