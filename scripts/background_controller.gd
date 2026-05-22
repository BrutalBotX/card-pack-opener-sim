extends TextureRect

# You need to drag your star/sparkle image here in the Inspector
@export var sparkle_texture: Texture2D 

func _process(_delta: float) -> void:
	# Calculate mouse tilt
	var mouse_pos = get_global_mouse_position()
	var screen_size = get_viewport_rect().size
	var normalized_mouse = (mouse_pos / screen_size) * 2.0 - Vector2.ONE
	
	# Pass to shader
	if material is ShaderMaterial:
		material.set_shader_parameter("mouse_pos", normalized_mouse)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		spawn_sparkle(event.position)

func spawn_sparkle(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	
	# Configure the particles via code so you don't need a separate node
	particles.position = pos
	particles.texture = sparkle_texture
	particles.amount = 5
	particles.lifetime = 1
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.spread = 180.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 0.5
	
	# Add to scene
	add_child(particles)
	particles.emitting = true
	
	# Clean up automatically after animation
	await particles.finished
	particles.queue_free()
