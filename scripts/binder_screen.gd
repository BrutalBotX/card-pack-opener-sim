extends Control

# State 1: Set Selection Menu
@onready var set_selection_state: Control = $SetSelectionState
@onready var set_grid_container: GridContainer = $SetSelectionState/ScrollContainer/CenterContainer/GridContainer

# State 2: Card Viewing Menu
@onready var card_view_state: Control = $CardViewState
@onready var back_button: Button = $CardViewState/VBoxContainer/BackButton
@onready var card_grid_container: GridContainer = $CardViewState/VBoxContainer/ScrollContainer/CenterContainer/GridContainer

const FALLBACK_IMAGE_PATH = "res://assets/packs/fallback.webp"

var card_db: Dictionary = {}
var set_groups: Dictionary = {} 
var set_names: Dictionary = {}  
var set_representatives: Dictionary = {} # Stores the cover image name for the set

func _ready() -> void:
	# Connect the back button
	back_button.pressed.connect(_on_back_pressed)
	
	load_master_database()
	build_set_selection_grid()

func load_master_database() -> void:
	# 1. Load sets.json to get the names and cover images
	var s_file = FileAccess.open("res://data/sets.json", FileAccess.READ)
	if s_file:
		var raw_sets = JSON.parse_string(s_file.get_as_text())
		if raw_sets:
			for series_key in raw_sets.keys():
				for s in raw_sets[series_key]:
					var raw_code = str(s.get("code", ""))
					var set_name = raw_code
					if typeof(s.get("name")) == TYPE_DICTIONARY:
						set_name = s.get("name").get("en", raw_code)
					
					set_names[raw_code] = set_name
					set_groups[raw_code] = []
					
					# Grab the first pack in the array to act as the Set Cover Art
					var packs = s.get("packs", [])
					if packs.size() > 0:
						set_representatives[raw_code] = str(packs[0])
					else:
						set_representatives[raw_code] = ""

	# 2. Load cards.json and group them by set
	var c_file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if c_file:
		var raw_cards = JSON.parse_string(c_file.get_as_text())
		if raw_cards:
			for card in raw_cards:
				var set_code = str(card.get("set", ""))
				var num_str = str(card.get("number", "")).trim_suffix(".0") 
				var c_id = set_code.to_upper() + "-" + num_str
				
				card_db[c_id] = {
					"image": card.get("image", "")
				}
				
				# Catch any weird unmapped sets
				if not set_groups.has(set_code):
					set_groups[set_code] = []
					set_names[set_code] = set_code
					set_representatives[set_code] = ""
					
				set_groups[set_code].append(c_id)

func build_set_selection_grid() -> void:
	set_selection_state.visible = true
	card_view_state.visible = false
	
	for child in set_grid_container.get_children():
		child.queue_free()
		
	for set_code in set_groups.keys():
		var item_vbox = VBoxContainer.new()
		item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		item_vbox.add_theme_constant_override("separation", 10)
		
		var set_btn = TextureButton.new()
		set_btn.custom_minimum_size = Vector2(180, 280)
		set_btn.ignore_texture_size = true
		set_btn.stretch_mode = TextureButton.STRETCH_SCALE
		set_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		# Find the pack wrapper image to use as the button
		var pack_name = set_representatives.get(set_code, "")
		var target_path = "res://assets/packs/" + pack_name + ".webp"
		
		if pack_name != "" and ResourceLoader.exists(target_path): 
			set_btn.texture_normal = load(target_path)
		elif ResourceLoader.exists(FALLBACK_IMAGE_PATH):
			set_btn.texture_normal = load(FALLBACK_IMAGE_PATH)
		else:
			set_btn.texture_normal = load("res://icon.svg")
			
		var name_label = Label.new()
		name_label.text = set_code + " - " + set_names[set_code]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_label.custom_minimum_size = Vector2(180, 0)
		
		# When clicked, open this specific set's binder
		set_btn.pressed.connect(func(): _on_set_selected(set_code))
		
		item_vbox.add_child(set_btn)
		item_vbox.add_child(name_label)
		set_grid_container.add_child(item_vbox)

func _on_set_selected(set_code: String) -> void:
	set_selection_state.visible = false
	card_view_state.visible = true
	build_binder_grid(set_code)

func _on_back_pressed() -> void:
	# Go back to the set selector
	set_selection_state.visible = true
	card_view_state.visible = false
	
	# CRITICAL: Destroy the loaded cards to prevent lag!
	for child in card_grid_container.get_children():
		child.queue_free()

func build_binder_grid(set_code: String) -> void:
	for child in card_grid_container.get_children():
		child.queue_free()
		
	var inventory: Dictionary = {}
	var sm = get_node_or_null("/root/SaveManager")
	if sm and sm.has_method("get_inventory"):
		var raw_inv = sm.get_inventory()
		if typeof(raw_inv) == TYPE_DICTIONARY:
			inventory = raw_inv
			
	var cards_in_set = set_groups[set_code]
	
	for c_id in cards_in_set:
		var card_data = card_db[c_id]
		var exact_image_name = card_data.get("image", "")
		var image_path = "res://assets/cards/" + exact_image_name
		
		var slot = TextureRect.new()
		slot.custom_minimum_size = Vector2(200, 280)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		if exact_image_name != "" and ResourceLoader.exists(image_path): 
			slot.texture = load(image_path)
		else: 
			slot.texture = load("res://icon.svg")
			
		var count_label = Label.new()
		count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		count_label.offset_left = -50
		count_label.offset_top = -40
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_font_size_override("font_size", 24)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		count_label.add_theme_constant_override("outline_size", 4)
		
		slot.add_child(count_label)
		
		# Illuminate collected cards, darken uncollected ones
		if inventory.has(c_id) and int(inventory[c_id]) > 0:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0) 
			count_label.text = "x" + str(int(inventory[c_id])) + " "
		else:
			slot.modulate = Color(0.1, 0.1, 0.1, 0.8) 
			count_label.text = ""
			
		card_grid_container.add_child(slot)
