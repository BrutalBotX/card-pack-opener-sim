extends Node3D

signal card_clicked_face_up 

@onready var visuals: Node3D = $Visuals
@onready var front_sprite: Sprite3D = $Visuals/Front
@onready var back_sprite: Sprite3D = $Visuals/Back
@onready var shine_particles: CPUParticles3D = $ShineParticles
@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D 

var is_mouse_over: bool = false
var card_dna: String = "Unknown Origin"
var pack_origin: String = "Unknown"
var card_id: String = ""
var card_name: String = ""
var rarity_code: String = ""
var is_special_rare: bool = false

var is_face_down: bool = true
var is_animating: bool = false

const MAX_TILT_ANGLE = 8.0  
const SMOOTH_SPEED = 8.0     
const TARGET_3D_HEIGHT = 8

# --- NEW: Holds our dynamic rarity icons ---
var rarity_container: Node3D

func _ready() -> void:
	if ResourceLoader.exists("res://assets/card_back.png"):
		back_sprite.texture = load("res://assets/card_back.png")
	elif ResourceLoader.exists("res://assets/card_back.webp"):
		back_sprite.texture = load("res://assets/card_back.webp")
	else:
		back_sprite.texture = load("res://icon.svg")
		
	if back_sprite.texture:
		back_sprite.pixel_size = TARGET_3D_HEIGHT / float(back_sprite.texture.get_height())
		
	visuals.rotation_degrees.y = 180

func setup_card(id: String, data: Dictionary, rarities_db: Dictionary, origin: String = "Unknown") -> void:
	card_id = id
	card_name = data.get("name", "Unknown")
	card_dna = origin
	rarity_code = data.get("rarity", "C")
	
	if rarities_db.has(rarity_code):
		if rarities_db[rarity_code].get("group", "") == "Star":
			is_special_rare = true
	
	var tex = AssetLoader.get_card_texture(data.get("image", ""))
	front_sprite.texture = tex
	
	var exact_width = TARGET_3D_HEIGHT * 0.7 
	if tex:
		front_sprite.pixel_size = TARGET_3D_HEIGHT / float(tex.get_height())
		var aspect_ratio = float(tex.get_width()) / float(tex.get_height())
		exact_width = TARGET_3D_HEIGHT * aspect_ratio
		
		if collision_shape and collision_shape.shape is BoxShape3D:
			collision_shape.shape.size = Vector3(exact_width, TARGET_3D_HEIGHT, 0.2)
			
	# --- NEW: Build the Rarity Icons dynamically ---
	if is_instance_valid(rarity_container):
		rarity_container.queue_free()
		
	rarity_container = Node3D.new()
	visuals.add_child(rarity_container)
	
	rarity_container.visible = false 
	rarity_container.scale = Vector3.ZERO
	
	# Position at the bottom-left edge, slightly below the artwork
	var x_start = (-exact_width / 2.0) + 0.2
	var y_pos = (-TARGET_3D_HEIGHT / 2.0) - 0.4 
	rarity_container.position = Vector3(x_start, y_pos, 0.05)
	
	if rarities_db.has(rarity_code):
		var r_info = rarities_db[rarity_code]
		var icon_img = r_info.get("image", "") # e.g. "diamond.webp"
		var count = int(r_info.get("count", 1)) # e.g. 4
		
		if icon_img != "":
			var base_path = "res://assets/rarities/" + icon_img
			var icon_tex = null
			
			# Check if the asset exists
			if ResourceLoader.exists(base_path):
				icon_tex = load(base_path)
			else:
				# Fallback just in case the file extension is different
				for ext in [".webp", ".png", ".jpg"]:
					if ResourceLoader.exists("res://assets/rarities/" + icon_img.get_basename() + ext):
						icon_tex = load("res://assets/rarities/" + icon_img.get_basename() + ext)
						break
						
			if icon_tex:
				var spacing = 0.45 # Distance between multiple icons (e.g. stacking 3 diamonds)
				for i in range(count):
					var icon_sprite = Sprite3D.new()
					icon_sprite.texture = icon_tex
					icon_sprite.pixel_size = 0.4 / float(icon_tex.get_height()) # Keep icons small and readable
					icon_sprite.position = Vector3(i * spacing, 0, 0)
					rarity_container.add_child(icon_sprite)

func _process(delta: float) -> void:
	if not is_face_down and not is_animating and is_mouse_over:
		var mouse_pos = get_viewport().get_mouse_position()
		var screen_size = get_viewport().get_visible_rect().size
		
		var mouse_rel = (mouse_pos / screen_size) * 2.0 - Vector2.ONE
		
		# 2. INVERTED MATH:
		# By swapping the signs, the card now tilts away from the mouse (inward).
		# We use (mouse_rel.y) instead of (-mouse_rel.y)
		# We use (-mouse_rel.x) instead of (mouse_rel.x)
		var target_rot = Vector3(mouse_rel.y * MAX_TILT_ANGLE, mouse_rel.x * MAX_TILT_ANGLE, 0)
		
		visuals.rotation_degrees = visuals.rotation_degrees.lerp(target_rot, delta * SMOOTH_SPEED)
	
	else:
		# Reset logic stays the same, ensure face-down cards stay at 180 Y
		var rest_rot = Vector3(0, 180, 0) if is_face_down else Vector3.ZERO
		visuals.rotation_degrees = visuals.rotation_degrees.lerp(rest_rot, delta * SMOOTH_SPEED)
		
func _on_area_3d_input_event(_camera, event, _position, _normal, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_face_down and not is_animating:
			reveal_card()
		elif not is_face_down and not is_animating:
			card_clicked_face_up.emit()

func reveal_card() -> void:
	is_animating = true
	var tween = create_tween()
	# --- DEBUG [BACKTRACKING] ---
	print("--- DEBUG [Card Reveal] ---")
	print("Card Name: ", card_name)
	print("Card ID:   ", card_id)
	print("Origin:    ", card_dna)
	print("Rarity:    ", rarity_code)
	print("---------------------------")
	
	# Flip the card visually
	tween.tween_property(visuals, "rotation_degrees:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.finished.connect(func():
		is_face_down = false
		is_animating = false
		
		if is_special_rare:
			shine_particles.emitting = true
			
		# Pop up the rarity icon with a juicy bounce animation
		if rarity_container and rarity_container.get_child_count() > 0:
			rarity_container.visible = true
			var pop_tween = create_tween()
			pop_tween.tween_property(rarity_container, "scale", Vector3(1, 1, 1), 0.3)\
				.from(Vector3.ZERO)\
				.set_trans(Tween.TRANS_BOUNCE)\
				.set_ease(Tween.EASE_OUT)
				
		# (Removed the accidental signal emission from here so it waits for your click!)
	)


func _on_area_3d_mouse_entered() -> void:
	print("DEBUG: Mouse Entered Card in: ", get_viewport().name)
	is_mouse_over = true


func _on_area_3d_mouse_exited() -> void:
	print("DEBUG: Mouse Exited Card")
	is_mouse_over = false
