extends RefCounted
class_name AssetLoader

const SUPPORTED_EXTENSIONS = [".webp", ".png", ".jpg", ".jpeg"]
const FALLBACK_PACK = "res://assets/packs/fallback.webp"
const FALLBACK_CARD = "res://icon.svg"

# ─────────────────────────────────────────────
#  JSON LOADING (The Bridge)
# ─────────────────────────────────────────────
static func load_json_data(file_name: String) -> Variant:
	# 1. Check user://data/ (The downloaded path)
	var user_path = "user://data/" + file_name
	if FileAccess.file_exists(user_path):
		var file = FileAccess.open(user_path, FileAccess.READ)
		var content = JSON.parse_string(file.get_as_text())
		file.close()
		return content

	# 2. Fallback to res://data/ (The packaged path)
	var res_path = "res://data/" + file_name
	if FileAccess.file_exists(res_path):
		var file = FileAccess.open(res_path, FileAccess.READ)
		var content = JSON.parse_string(file.get_as_text())
		file.close()
		return content
		
	push_error("JSON file missing in both user://data/ and res://data/: " + file_name)
	return null

# ─────────────────────────────────────────────
#  IMAGE LOADING HELPERS
# ─────────────────────────────────────────────
static func _try_load_image(path: String) -> Texture2D:
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

# ─────────────────────────────────────────────
#  PACK TEXTURES
# ─────────────────────────────────────────────
static func get_pack_texture(pack_name: String) -> Texture2D:
	# 1. Custom Override Check for Promos
	if pack_name == "Promo Pack":
		var custom_promo_path = "res://assets/packs/promo.webp"
		if ResourceLoader.exists(custom_promo_path):
			return load(custom_promo_path)

	# 2. Check user://assets/packs/
	for ext in SUPPORTED_EXTENSIONS:
		var tex = _try_load_image("user://assets/packs/" + pack_name + ext)
		if tex: return tex

	# 3. Fall back to res://assets/packs/
	for ext in SUPPORTED_EXTENSIONS:
		var res_path = "res://assets/packs/" + pack_name + ext
		if ResourceLoader.exists(res_path): return load(res_path)

	return load(FALLBACK_PACK) if ResourceLoader.exists(FALLBACK_PACK) else load(FALLBACK_CARD)

# ─────────────────────────────────────────────
#  CARD TEXTURES
# ─────────────────────────────────────────────
static func get_card_texture(image_name: String) -> Texture2D:
	# 1. Check user://assets/cards/
	var tex = _try_load_image("user://assets/cards/" + image_name)
	if tex: return tex

	# 2. Fall back to res://assets/cards/
	var res_path = "res://assets/cards/" + image_name
	if ResourceLoader.exists(res_path): return load(res_path)

	# 3. Generic fallback
	return load("res://assets/cards/fallback.webp") if ResourceLoader.exists("res://assets/packs/fallback.webp") else load(FALLBACK_CARD)

# ─────────────────────────────────────────────
#  SET LOGO TEXTURES
# ─────────────────────────────────────────────
static func get_set_logo_texture(set_code: String) -> Texture2D:
	# 1. Custom Override Check for Promo Logo
	if set_code == "PROMO":
		var custom_logo_path = "res://assets/sets/LOGO_expansion_PROMO-A_en_US.webp"
		if ResourceLoader.exists(custom_logo_path):
			return load(custom_logo_path)

	# 2. Check user://assets/sets/ (downloaded)
	var file_name = "LOGO_expansion_" + set_code + "_en_US.webp"
	var tex = _try_load_image("user://assets/sets/" + file_name)
	if tex: return tex

	# 3. Fall back to res://assets/sets/ (bundled)
	var res_path = "res://assets/sets/" + file_name
	if ResourceLoader.exists(res_path): return load(res_path)

	return null

# ─────────────────────────────────────────────
#  UTILITIES
# ─────────────────────────────────────────────
static func generate_card_id(set_code: String, card_number: String) -> String:
	return set_code.to_upper() + "-" + card_number.trim_suffix(".0")
