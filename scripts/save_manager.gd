extends RefCounted
class_name SaveManager

const SAVE_PATH = "user://inventory.json"

# Master function to load the player's binder collection
static func load_inventory() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Creating a fresh, empty binder.")
		return {} # Return an empty dictionary if it's a first-time player
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		return json.data
		
	return {}

# Master function to save the binder collection to disk
static func save_inventory(inventory: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_string = JSON.stringify(inventory)
	file.store_string(json_string)
	file.close()
	print("Inventory permanently saved to offline storage!")

# Helper function to add a batch of pulled cards to the inventory
static func add_cards_to_inventory(card_ids: Array[String]) -> void:
	var current_inventory = load_inventory()
	
	for id in card_ids:
		if current_inventory.has(id):
			current_inventory[id] += 1 # Increase count if we already own it
		else:
			current_inventory[id] = 1  # Add it to the binder if it's new
			
	save_inventory(current_inventory)
