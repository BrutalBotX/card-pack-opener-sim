extends Node

var save_path = "user://tcg_inventory.save"
var inventory: Dictionary = {}

func _ready() -> void:
	load_inventory()

func add_cards_to_inventory(new_card_ids: Array) -> void:
	var inventory: Dictionary = {}
	var path = "user://inventory.json"
	
	# 1. Load existing inventory first so we don't delete everything else!
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			inventory = parsed

	# 2. Add the newly pulled cards to the dictionary
	for c_id in new_card_ids:
		if inventory.has(c_id):
			inventory[c_id] += 1
		else:
			inventory[c_id] = 1

	# 3. Save it back to the disk
	var save_file = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_string(JSON.stringify(inventory))
	save_file.close()
	
	print("SUCCESS: Saved ", new_card_ids.size(), " new cards to disk!")

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
