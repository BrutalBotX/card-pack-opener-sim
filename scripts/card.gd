extends Node3D

signal card_clicked_face_up 

@onready var visuals: Node3D = $Visuals
@onready var front_sprite: Sprite3D = $Visuals/Front
@onready var back_sprite: Sprite3D = $Visuals/Back
@onready var shine_particles: CPUParticles3D = $ShineParticles

var card_id: String = ""
var card_name: String = ""
var rarity_code: String = ""
var is_special_rare: bool = false

var is_face_down: bool = true
var is_animating: bool = false

const MAX_TILT_ANGLE = 15.0  
const SMOOTH_SPEED = 8.0     

func _ready() -> void:
	if ResourceLoader.exists("res://assets/card_back.png"):
		back_sprite.texture = load("res://assets/card_back.png")
	elif ResourceLoader.exists("res://assets/card_back.webp"):
		back_sprite.texture = load("res://assets/card_back.webp")
	else:
		back_sprite.texture = load("res://icon.svg")
		
	visuals.rotation_degrees.y = 180

func setup_card(id: String, data: Dictionary, rarities_db: Dictionary) -> void:
	card_id = id
	card_name = data["name"]
	rarity_code = data["rarity"]
	
	if rarities_db.has(rarity_code):
		var rarity_group = rarities_db[rarity_code].get("group", "")
		if rarity_group == "Star" or rarity_code == "RR":
			is_special_rare = true
	
	# Strictly grab the messy GitHub filename
	var exact_image_name = data.get("image", "")
	var image_path = "res://assets/cards/" + exact_image_name
	
	if exact_image_name != "" and ResourceLoader.exists(image_path): 
		front_sprite.texture = load(image_path)
	else:
		print("Warning: Missing artwork asset at exact path: ", image_path)
		front_sprite.texture = load("res://icon.svg")

func _process(delta: float) -> void:
	if is_face_down or is_animating: return
		
	var target_rotation = Vector3.ZERO
	if OS.get_name() in ["Android", "iOS"]:
		var gravity = Input.get_gravity()
		var tilt_x = clamp(gravity.x / 9.8, -1.0, 1.0)
		var tilt_y = clamp(gravity.y / 9.8, -1.0, 1.0)
		target_rotation.y = -tilt_x * MAX_TILT_ANGLE
		target_rotation.x = -tilt_y * MAX_TILT_ANGLE
	else:
		var viewport_size = get_viewport().get_visible_rect().size
		var mouse_pos = get_viewport().get_mouse_position()
		var center_offset_x = (mouse_pos.x / viewport_size.x) - 0.5
		var center_offset_y = (mouse_pos.y / viewport_size.y) - 0.5
		target_rotation.y = center_offset_x * MAX_TILT_ANGLE
		target_rotation.x = center_offset_y * MAX_TILT_ANGLE

	visuals.rotation.x = lerp(visuals.rotation.x, deg_to_rad(target_rotation.x), delta * SMOOTH_SPEED)
	visuals.rotation.y = lerp(visuals.rotation.y, deg_to_rad(target_rotation.y), delta * SMOOTH_SPEED)

func _on_area_3d_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_face_down and not is_animating:
			reveal_card()
		elif not is_face_down and not is_animating:
			card_clicked_face_up.emit()

func reveal_card() -> void:
	is_animating = true
	var tween = create_tween()
	
	tween.tween_property(visuals, "rotation_degrees:y", 0.0, 0.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	tween.finished.connect(func():
		is_face_down = false
		is_animating = false
		if is_special_rare: 
			shine_particles.emitting = true
	)
