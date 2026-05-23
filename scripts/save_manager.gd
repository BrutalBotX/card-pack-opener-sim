extends Node

var save_path = "user://tcg_inventory.save"
var inventory: Dictionary = {}

func _ready() -> void:
	load_inventory()

func add_cards_to_inventory(new_card_ids: Array) -> void:
	# CHANGE 1: Rename this from 'inventory' to 'temp_inventory'
	var temp_inventory: Dictionary = {} 
	var path = "user://inventory.json"
	
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			temp_inventory = parsed # CHANGE 2

	for c_id in new_card_ids:
		if temp_inventory.has(c_id): # CHANGE 3
			temp_inventory[c_id] += 1
		else:
			temp_inventory[c_id] = 1

	var save_file = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_string(JSON.stringify(temp_inventory)) # CHANGE 4
	save_file.close()

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
