extends RefCounted
class_name AssetLoader

const SUPPORTED_EXTENSIONS = [".webp", ".png", ".jpg", ".jpeg"]
const FALLBACK_PACK = "res://assets/packs/fallback.webp"
const FALLBACK_CARD = "res://icon.svg"

# ─────────────────────────────────────────────
#  PACK TEXTURES
# ─────────────────────────────────────────────
static func get_pack_texture(pack_name: String) -> Texture2D:
	# 1. Check user:// (downloaded assets on Android)
	for ext in SUPPORTED_EXTENSIONS:
		var user_path = "user://assets/packs/" + pack_name + ext
		if FileAccess.file_exists(user_path):
			var img = Image.load_from_file(user_path)
			if img != null and not img.is_empty():
				return ImageTexture.create_from_image(img)
			else:
				push_error("Pack image found but failed to load: " + user_path)

	# 2. Fall back to res:// (bundled assets)
	for ext in SUPPORTED_EXTENSIONS:
		var res_path = "res://assets/packs/" + pack_name + ext
		if ResourceLoader.exists(res_path):
			return load(res_path)

	# 3. Generic fallback
	if ResourceLoader.exists(FALLBACK_PACK):
		return load(FALLBACK_PACK)

	return load(FALLBACK_CARD)

# ─────────────────────────────────────────────
#  CARD TEXTURES
# ─────────────────────────────────────────────
static func get_card_texture(image_name: String) -> Texture2D:
	# 1. Check user:// (downloaded assets on Android)
	var user_path = "user://assets/cards/" + image_name
	if FileAccess.file_exists(user_path):
		var img = Image.load_from_file(user_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
		else:
			push_error("Card image found but failed to load: " + user_path)

	# 2. Fall back to res:// (bundled assets)
	var res_path = "res://assets/cards/" + image_name
	if ResourceLoader.exists(res_path):
		return load(res_path)

	# 3. Generic fallback card image
	var fallback_path = "res://assets/cards/fallback.webp"
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path)

	return load(FALLBACK_CARD)

# ─────────────────────────────────────────────
#  SET LOGO TEXTURES
# ─────────────────────────────────────────────
static func get_set_logo_texture(set_code: String) -> Texture2D:
	var file_name = "LOGO_expansion_" + set_code + "_en_US.webp"

	# 1. Check user://assets/sets/ (downloaded)
	var user_path = "user://assets/sets/" + file_name
	if FileAccess.file_exists(user_path):
		var img = Image.load_from_file(user_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
		else:
			push_error("Set logo found but failed to load: " + user_path)

	# 2. Fall back to res://assets/sets/ (bundled, if any)
	var res_path = "res://assets/sets/" + file_name
	if ResourceLoader.exists(res_path):
		return load(res_path)

	# 3. Return null so the UI can fall back to showing text instead
	return null

# ─────────────────────────────────────────────
#  UTILITIES
# ─────────────────────────────────────────────
static func generate_card_id(set_code: String, card_number: String) -> String:
	return set_code.to_upper() + "-" + card_number.trim_suffix(".0")
