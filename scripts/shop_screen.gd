extends Control

@onready var pack_grid_state: Control = $PackGridState
# Remember to wrap your GridContainer in a CenterContainer in the editor!
@onready var pack_grid_container: GridContainer = $PackGridState/ScrollContainer/CenterContainer/GridContainer

@onready var carousel_state: Control = $CarouselState
@onready var scroll_container: ScrollContainer = $CarouselState/ScrollContainer
@onready var carousel_hbox: HBoxContainer = $CarouselState/ScrollContainer/HBoxContainer

@onready var tear_and_reveal_state: Control = $TearAndRevealState
@onready var pack_viewport: SubViewport = $TearAndRevealState/SubViewportContainer/SubViewport

const CARD_SCENE = preload("res://scenes/card.tscn")
const FALLBACK_IMAGE_PATH = "res://assets/packs/fallback.webp"

var card_db: Dictionary = {}
var pack_config: Dictionary = {}
var pull_rates: Dictionary = {}
var rarities_db: Dictionary = {}

var selected_pack_id: String = ""
var current_pack_card_ids: Array[String] = []
var active_spawned_card: Node3D = null

var single_set_width: float = 0.0
var is_carousel_ready: bool = false

# Network & UI Nodes for the Long Press Info Box
var http_request: HTTPRequest
var info_dialog: AcceptDialog

func _ready() -> void:
	# Setup the Network Downloader
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_history_request_completed)
	
	# Setup the Pop-up Window
	info_dialog = AcceptDialog.new()
	info_dialog.title = "Pack History"
	info_dialog.dialog_text = "Loading data from the internet..."
	info_dialog.dialog_autowrap = true # Godot 4 Specific syntax applied!
	add_child(info_dialog)
	
	load_master_database()
	build_pack_selection_grid()

func load_master_database() -> void:
	var c_file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if c_file:
		var raw_cards = JSON.parse_string(c_file.get_as_text())
		if raw_cards:
			card_db.clear()
			for card in raw_cards:
				var set_code = str(card.get("set", "")).to_upper()
				var num_str = str(card.get("number", "")).trim_suffix(".0") 
				var c_id = set_code + "-" + num_str 
				
				card_db[c_id] = {
					"name": card.get("name", "Unknown"),
					"rarity": str(card.get("rarity", "C")),
					"type": str(card.get("element", "Colorless")),
					"set": set_code,
					"number": num_str,
					"packs": card.get("packs", []),
					"image": card.get("image", "") 
				}

	var s_file = FileAccess.open("res://data/sets.json", FileAccess.READ)
	if s_file:
		var raw_sets = JSON.parse_string(s_file.get_as_text())
		if raw_sets:
			pack_config.clear()
			for series_key in raw_sets.keys():
				for s in raw_sets[series_key]:
					var raw_code = str(s.get("code", ""))
					var set_name = raw_code
					
					if typeof(s.get("name")) == TYPE_DICTIONARY:
						set_name = s.get("name").get("en", raw_code)
						
					var packs = s.get("packs", [set_name])
					if packs.is_empty(): packs = [set_name]
						
					for p_name in packs:
						var p_id = raw_code.to_upper() + "|" + str(p_name)
						
						var count = 5
						if raw_code.to_upper() != raw_code: count = 3
						if "PROMO" in p_id: count = 1
						
						pack_config[p_id] = {
							"set_code": raw_code,
							"pack_name": str(p_name), 
							"set_name": set_name,
							"card_count": count
						}

	var pr_file = FileAccess.open("res://data/pullRates.json", FileAccess.READ)
	if pr_file: pull_rates = JSON.parse_string(pr_file.get_as_text())

	var r_file = FileAccess.open("res://data/rarities.json", FileAccess.READ)
	if r_file: rarities_db = JSON.parse_string(r_file.get_as_text())

func build_pack_selection_grid() -> void:
	for child in pack_grid_container.get_children(): child.queue_free()
	
	pack_grid_state.visible = true
	carousel_state.visible = false
	tear_and_reveal_state.visible = false
	
	for p_id in pack_config.keys():
		var p_conf = pack_config[p_id]
		
		# Create a Vertical Box to stack the Image and Text
		var item_vbox = VBoxContainer.new()
		item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_vbox.add_theme_constant_override("separation", 10)
		
		var pack_btn = TextureButton.new()
		pack_btn.custom_minimum_size = Vector2(180, 280)
		pack_btn.ignore_texture_size = true
		pack_btn.stretch_mode = TextureButton.STRETCH_SCALE
		pack_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		var target_path = "res://assets/packs/" + p_conf["pack_name"] + ".webp"
		
		# Fallback Image Logic
		if ResourceLoader.exists(target_path): 
			pack_btn.texture_normal = load(target_path)
		elif ResourceLoader.exists(FALLBACK_IMAGE_PATH):
			pack_btn.texture_normal = load(FALLBACK_IMAGE_PATH)
		else:
			pack_btn.texture_normal = load("res://icon.svg") 
			
		# Text Label Below Pack
		var name_label = Label.new()
		name_label.text = p_conf["pack_name"]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_label.custom_minimum_size = Vector2(180, 0)
		
		# Custom Long-Press Logic
		pack_btn.set_meta("press_start_time", 0)
		pack_btn.set_meta("is_long_press", false)
		
		pack_btn.button_down.connect(func():
			pack_btn.set_meta("press_start_time", Time.get_ticks_msec())
			pack_btn.set_meta("is_long_press", false)
		)
		
		pack_btn.button_up.connect(func():
			var press_duration = Time.get_ticks_msec() - pack_btn.get_meta("press_start_time")
			# If held for more than 600 milliseconds, it's a long press!
			if press_duration > 600:
				pack_btn.set_meta("is_long_press", true)
				_trigger_history_fetch(p_conf["pack_name"])
		)
		
		pack_btn.pressed.connect(func():
			# Only open the pack if they didn't just trigger the long-press info box
			if not pack_btn.get_meta("is_long_press"):
				_on_pack_type_selected(p_id)
		)
		
		item_vbox.add_child(pack_btn)
		item_vbox.add_child(name_label)
		pack_grid_container.add_child(item_vbox)

# Network Fetching Logic
func _trigger_history_fetch(pack_name: String) -> void:
	info_dialog.title = pack_name + " History"
	info_dialog.dialog_text = "Connecting to database..."
	info_dialog.popup_centered(Vector2(400, 300))
	
	# Placeholder API Request
	var url = "https://jsonplaceholder.typicode.com/posts/1" 
	var error = http_request.request(url)
	
	if error != OK:
		info_dialog.dialog_text = "Error: Could not connect to the internet."

func _on_history_request_completed(result, response_code, headers, body) -> void:
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			info_dialog.dialog_text = "Live API Data:\n\n" + json.get("body", "No description found.")
	else:
		info_dialog.dialog_text = "Failed to download history. Server returned code: " + str(response_code)

func _on_pack_type_selected(p_id: String) -> void:
	selected_pack_id = p_id
	open_pack_carousel_illusion()

func open_pack_carousel_illusion() -> void:
	pack_grid_state.visible = false
	carousel_state.visible = true
	is_carousel_ready = false
	
	for child in carousel_hbox.get_children(): child.queue_free()
	
	for i in range(15):
		var pack_option = TextureButton.new()
		pack_option.custom_minimum_size = Vector2(250, 420)
		pack_option.ignore_texture_size = true
		pack_option.stretch_mode = TextureButton.STRETCH_SCALE
		
		var p_conf = pack_config[selected_pack_id]
		var target_path = "res://assets/packs/" + p_conf["pack_name"] + ".webp"
		
		if ResourceLoader.exists(target_path): 
			pack_option.texture_normal = load(target_path)
		elif ResourceLoader.exists(FALLBACK_IMAGE_PATH):
			pack_option.texture_normal = load(FALLBACK_IMAGE_PATH)
		else:
			pack_option.texture_normal = load("res://icon.svg")
			
		pack_option.pressed.connect(start_pack_tear_sequence)
		carousel_hbox.add_child(pack_option)
		
	await get_tree().process_frame
	
	if carousel_hbox.get_child_count() > 5:
		single_set_width = carousel_hbox.get_child(5).position.x
		scroll_container.scroll_horizontal = int(single_set_width)
		is_carousel_ready = true

func _process(_delta: float) -> void:
	if not is_carousel_ready or not carousel_state.visible: return

	if scroll_container.scroll_horizontal < 10:
		scroll_container.scroll_horizontal += int(single_set_width)
	elif scroll_container.scroll_horizontal > int(single_set_width * 2) - 10:
		scroll_container.scroll_horizontal -= int(single_set_width)

func start_pack_tear_sequence() -> void:
	carousel_state.visible = false
	tear_and_reveal_state.visible = true
	
	var rolled_pack = PackGenerator.generate_pack(card_db, selected_pack_id, pack_config, pull_rates)
	
	current_pack_card_ids.clear()
	current_pack_card_ids.assign(rolled_pack)
	
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("add_cards_to_inventory"):
		sm.add_cards_to_inventory(current_pack_card_ids)
		
	spawn_next_card_in_sequence()

func spawn_next_card_in_sequence() -> void:
	if current_pack_card_ids.is_empty():
		build_pack_selection_grid()
		return
		
	var next_id = current_pack_card_ids.pop_front()
	
	# === THE CRASH SHIELD ===
	# Safely skips if datamine JSON threw out a bad ID
	if not card_db.has(next_id):
		print("ERROR: Card ID not found in database: ", next_id)
		advance_pack_deck() 
		return
	# ========================
	
	active_spawned_card = CARD_SCENE.instantiate()
	pack_viewport.add_child(active_spawned_card)
	active_spawned_card.card_clicked_face_up.connect(advance_pack_deck)
	active_spawned_card.position = Vector3(0, 0, 0)
	
	active_spawned_card.setup_card(next_id, card_db[next_id], rarities_db)

func advance_pack_deck() -> void:
	if active_spawned_card != null:
		active_spawned_card.queue_free()
		active_spawned_card = null
		spawn_next_card_in_sequence()
