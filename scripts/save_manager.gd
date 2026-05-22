extends Node

var save_path = "user://tcg_inventory.save"
var inventory: Dictionary = {}

func _ready() -> void:
	load_inventory()

func add_cards_to_inventory(card_ids: Array[String]) -> void:
	# Adds the pulled cards to your collection and saves them instantly
	for c_id in card_ids:
		if inventory.has(c_id):
			inventory[c_id] += 1
		else:
			inventory[c_id] = 1
	save_inventory()

func get_inventory() -> Dictionary:
	return inventory

func save_inventory() -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(inventory))

func load_inventory() -> void:
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				inventory = data
