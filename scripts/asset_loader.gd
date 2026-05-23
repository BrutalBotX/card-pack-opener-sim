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

# ADDED 'static' KEYWORD HERE
static func get_card_texture(image_name: String) -> Texture2D:
	# 1. Check if we downloaded it to the device (user://)
	var user_path = "user://assets/cards/" + image_name
	if FileAccess.file_exists(user_path):
		var img = Image.load_from_file(user_path)
		# Safety check: make sure the image actually loaded and isn't corrupted
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
		else:
			push_error("Image file found but failed to load: " + user_path)
		
	# 2. Fallback to the packaged version if it isn't downloaded
	var res_path = "res://assets/cards/" + image_name
	if ResourceLoader.exists(res_path):
		return load(res_path)
		
	# 3. Final Fallback
	var fallback_path = "res://assets/cards/fallback.webp"
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path)
		
	return load(FALLBACK_CARD)

# Centralized ID Generator
static func generate_card_id(set_code: String, card_number: String) -> String:
	return set_code.to_upper() + "-" + card_number.trim_suffix(".0")
