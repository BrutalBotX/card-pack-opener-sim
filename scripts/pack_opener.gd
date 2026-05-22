extends Control

signal pack_ripped  # We fire this when a valid swipe happens!

@onready var pack_wrapper: TextureRect = $PackWrapper

# Gesture Tracking Variables
var swipe_start_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false

# Configuration Rules for a "Valid" Swipe
const MIN_SWIPE_DISTANCE = 100.0  # Must drag at least 100 pixels
const MAX_SWIPE_TIME = 0.4        # Swipe must happen fast (under 0.4 seconds)
var swipe_start_time: float = 0.0

func _input(event: InputEvent) -> void:
	# Works globally for both Mouse Clicks and Mobile Touch events
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.is_pressed():
			# User pressed down anywhere on the screen
			start_swipe_tracking(event.position)
		elif not event.is_pressed() and is_dragging:
			# User lifted their finger anywhere on the screen
			end_swipe_tracking(event.position)

func start_swipe_tracking(pos: Vector2) -> void:
	# FIXED: Removed the bounding box restriction. 
	# The gesture engine will now track the path no matter where it starts!
	swipe_start_pos = pos
	swipe_start_time = Time.get_ticks_msec() / 1000.0
	is_dragging = true

func end_swipe_tracking(end_pos: Vector2) -> void:
	is_dragging = false
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_elapsed = current_time - swipe_start_time
	
	# Calculate total distance traveled
	var swipe_vector = end_pos - swipe_start_pos
	var swipe_distance = swipe_vector.length()
	
	# Check if the slash met our speed and distance requirements
	if swipe_distance >= MIN_SWIPE_DISTANCE and time_elapsed <= MAX_SWIPE_TIME:
		execute_pack_tear()

func execute_pack_tear() -> void:
	print("BOOM! Pack wrapper torn open.")
	pack_ripped.emit()
	
	# Play a clean visual fade-out animation for the pack wrapper image
	var tween = create_tween()
	tween.tween_property(pack_wrapper, "modulate:a", 0.0, 0.3)
	tween.finished.connect(queue_free) # Delete the wrapper overlay once faded
