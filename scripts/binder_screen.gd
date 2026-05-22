extends Control

# State 1: Set Selection Menu
@onready var set_selection_state: Control = $SetSelectionState
@onready var set_grid_container: GridContainer = %SetSelectionGrid

# State 2: Card Viewing Menu
@onready var card_view_state: Control = $CardViewState
@onready var card_grid_container: GridContainer = %BinderCardGrid

const CARD_SCENE = preload("res://scenes/card.tscn")
const FALLBACK_IMAGE_PATH = "res://assets/packs/fallback.webp"

var card_db: Dictionary = {}
var set_groups: Dictionary = {} 
var set_names: Dictionary = {}  
var set_representatives: Dictionary = {} 
var rarities_db: Dictionary = {}

var active_3d_popup: Control = null

func load_inventory() -> void:
	var path = "user://inventory.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var content = file.get_as_text()
		print("DEBUG: Inventory file found. Size: ", content.length(), " characters.")
		var data = JSON.parse_string(content)
		if data == null:
			print("ERROR: Inventory.json is corrupted!")
		else:
			print("DEBUG: Loaded ", data.size(), " cards from inventory.")
	else:
		print("DEBUG: No inventory.json found at ", path)
		

func _ready() -> void:
	load_master_database()
	build_set_selection_grid()
	
	
func load_master_database() -> void:
	var s_file = FileAccess.open("res://data/sets.json", FileAccess.READ)
	if s_file:
		var raw_sets = JSON.parse_string(s_file.get_as_text())
		if raw_sets:
			for series_key in raw_sets.keys():
				for s in raw_sets[series_key]:
					var raw_code = str(s.get("code", ""))
					var display_code = raw_code
					var parsed_set_name = raw_code
					
					if typeof(s.get("name")) == TYPE_DICTIONARY:
						parsed_set_name = s.get("name").get("en", raw_code)
						
					# --- SMART ADAPTER: Consolidate Promos ---
					if raw_code.to_upper().begins_with("PROMO"):
						display_code = "PROMO"
						parsed_set_name = "Promotional Cards"
					
					if not set_names.has(display_code):
						set_names[display_code] = parsed_set_name
						set_groups[display_code] = []
						
						var packs = s.get("packs", [])
						
						# FIX: Force the binder to use the unified Promo Pack image
						if display_code == "PROMO":
							set_representatives[display_code] = "Promo Pack"
						elif packs.size() > 0:
							set_representatives[display_code] = str(packs[0])
						else:
							set_representatives[display_code] = ""

	var r_file = FileAccess.open("res://data/rarities.json", FileAccess.READ)
	if r_file: 
		rarities_db = JSON.parse_string(r_file.get_as_text())

	var c_file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if c_file:
		var raw_cards = JSON.parse_string(c_file.get_as_text())
		if raw_cards:
			for card in raw_cards:
				var set_code = str(card.get("set", ""))
				var num_str = str(card.get("number", "")) 
				var c_id = AssetLoader.generate_card_id(set_code, num_str)
				
				card_db[c_id] = {
					"name": card.get("name", "Unknown"),
					"rarity": str(card.get("rarity", "C")),
					"image": card.get("image", "")
				}
				
				# --- SMART ADAPTER: Group into the consolidated set ---
				var display_code = set_code 
				
				# We still want to safely catch Promos, so we use to_upper() only for the check
				if display_code.to_upper().begins_with("PROMO"):
					display_code = "PROMO"
					
				if not set_groups.has(display_code):
					set_groups[display_code] = []
					# Give it a safe fallback name
					set_names[display_code] = "Promotional Cards" if display_code == "PROMO" else display_code
					set_representatives[display_code] = "Promo Pack" if display_code == "PROMO" else ""
					
				set_groups[display_code].append(c_id)
			
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
		
		var pack_name = set_representatives.get(set_code, "")
				
		# DATA-DRIVEN FIX: Let the AssetLoader find the correct extension
		set_btn.texture_normal = AssetLoader.get_pack_texture(pack_name)
			
		var name_label = Label.new()
		name_label.text = set_code + " - " + set_names[set_code]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_label.custom_minimum_size = Vector2(180, 0)
		
		set_btn.pressed.connect(func(): _on_set_selected(set_code))
		
		item_vbox.add_child(set_btn)
		item_vbox.add_child(name_label)
		set_grid_container.add_child(item_vbox)

func _on_set_selected(set_code: String) -> void:
	set_selection_state.visible = false
	card_view_state.visible = true
	build_binder_grid(set_code)

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
		var is_owned = inventory.has(c_id) and int(inventory[c_id]) > 0
		var exact_image_name = card_data.get("image", "")
		
		# 1. Standard Lightweight 2D Grid Setup
		var slot = TextureRect.new()
		slot.custom_minimum_size = Vector2(200, 280)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# DATA-DRIVEN FIX: One line to load the texture safely!
		slot.texture = AssetLoader.get_card_texture(exact_image_name)
			
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
		
		# 2. Dynamic Interaction Logic
		if is_owned:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0) 
			count_label.text = "x" + str(int(inventory[c_id])) + " "
			
			# Make the 2D slot detect mouse/touch input
			slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					spawn_3d_inspection_popup(c_id, card_data)
			)
		else:
			slot.modulate = Color(0.1, 0.1, 0.1, 0.8) # Gray out unowned
			count_label.text = ""
			
		card_grid_container.add_child(slot)

# --- Full-Screen 3D Pop-up System ---
func spawn_3d_inspection_popup(c_id: String, card_data: Dictionary) -> void:
	# Clean up any existing pop-up just in case
	if active_3d_popup != null:
		active_3d_popup.queue_free()
	
	
	# 1. Create a dark, slightly transparent background block
	active_3d_popup = ColorRect.new()
	active_3d_popup.color = Color(0, 0, 0, 0.85) 
	active_3d_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	active_3d_popup.z_index = 100 # Keep it on top of the UI
	
	# Close the pop-up if the user taps anywhere on the dark background
	active_3d_popup.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			active_3d_popup.queue_free()
			active_3d_popup = null
	)
	
	add_child(active_3d_popup)
	
	# 2. Create a Full-Screen 3D Viewport with Padding
	var viewport_container = SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) 
	
	# --- NEW: Wiggle Room / Padding ---
	viewport_container.offset_left = 40
	viewport_container.offset_top = 80 # Extra room for phone notches/status bars
	viewport_container.offset_right = -40
	viewport_container.offset_bottom = -120 # Keeps the card away from the hint text
	
	viewport_container.stretch = true
	
	# Pass clicks through to the background block so you can close it
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	active_3d_popup.add_child(viewport_container)
	
	var viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.physics_object_picking = true 
	viewport_container.add_child(viewport)
	
	# 3. Add 3D Lighting and Camera
	var cam = Camera3D.new()
	cam.position = Vector3(0, 0, 6) 
	viewport.add_child(cam)
	
	var light = DirectionalLight3D.new()
	viewport.add_child(light)
	
	# 4. Instantiate the actual 3D Interactive Card Scene
	var card_instance = CARD_SCENE.instantiate()
	viewport.add_child(card_instance)
	
	# Configure the card visual and skip the flip animation
	card_instance.setup_card(c_id, card_data, rarities_db)
	card_instance.is_face_down = false
	card_instance.visuals.rotation_degrees.y = 0 
	
	if card_instance.is_special_rare:
		card_instance.shine_particles.emitting = true

	# 5. Add a hint label at the bottom
	var hint = Label.new()
	hint.text = "Tap anywhere to close"
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -60
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	active_3d_popup.add_child(hint)
