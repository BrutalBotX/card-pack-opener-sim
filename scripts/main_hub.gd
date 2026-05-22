extends Control

# Hardcode the paths to our screens for lightning-fast memory preloading
const SHOP_SCREEN = preload("res://scenes/shop_screen.tscn")
const BINDER_SCREEN = preload("res://scenes/binder_screen.tscn")

@onready var screen_container: Control = $ScreenContainer
@onready var btn_shop: Button = $BottomNavBar/BtnShop
@onready var btn_binder: Button = $BottomNavBar/BtnBinder

# Keep track of whatever screen is currently active on the display
var current_active_screen: Node = null

func _ready() -> void:
	# Connect the standard UI press signals directly to our routing logic
	btn_shop.pressed.connect(_on_shop_pressed)
	btn_binder.pressed.connect(_on_binder_pressed)
	
	# Boot up the game straight into the Shop/Pack screen by default
	switch_screen(SHOP_SCREEN)

func switch_screen(new_screen_resource: PackedScene) -> void:
	# 1. Clean up duty: If a screen is already open, delete it cleanly from memory
	if current_active_screen != null:
		current_active_screen.queue_free()
	
	# 2. Instantiate the new target screen blueprint
	var new_screen = new_screen_resource.instantiate()
	
	# 3. Drop it inside our designated frame container
	screen_container.add_child(new_screen)
	
	# 4. Ensure the new screen stretches perfectly to fill the container frame
	if new_screen is Control:
		new_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	# 5. Update our tracking reference
	current_active_screen = new_screen

func _on_shop_pressed() -> void:
	switch_screen(SHOP_SCREEN)

func _on_binder_pressed() -> void:
	switch_screen(BINDER_SCREEN)
