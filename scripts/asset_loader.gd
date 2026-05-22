extends RefCounted
class_name AssetLoader

const SUPPORTED_EXTENSIONS = [".webp", ".png", ".jpg", ".jpeg"]
const FALLBACK_PACK = "res://assets/packs/fallback.webp"
const FALLBACK_CARD = "res://icon.svg"

static func get_pack_texture(pack_name: String) -> Texture2D:
	var base_path = "res://assets/packs/" + pack_name
	
	for ext in SUPPORTED_EXTENSIONS:
		if ResourceLoader.exists(base_path + ext):
			return load(base_path + ext)
			
	if ResourceLoader.exists(FALLBACK_PACK):
		return load(FALLBACK_PACK)
		
	return load(FALLBACK_CARD)

static func get_card_texture(exact_image_name: String) -> Texture2D:
	# If the JSON already provides the extension (e.g. "pikachu.webp")
	if "." in exact_image_name:
		var full_path = "res://assets/cards/" + exact_image_name
		if ResourceLoader.exists(full_path):
			return load(full_path)
			
	# If the JSON only provides the name (e.g. "pikachu")
	var base_path = "res://assets/cards/" + exact_image_name
	for ext in SUPPORTED_EXTENSIONS:
		if ResourceLoader.exists(base_path + ext):
			return load(base_path + ext)
			
	return load(FALLBACK_CARD)

# Centralized ID Generator
static func generate_card_id(set_code: String, card_number: String) -> String:
	return set_code.to_upper() + "-" + card_number.trim_suffix(".0")
