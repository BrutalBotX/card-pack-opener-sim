extends Node
class_name PackGenerator

# STEP 1: Roll the 99.95% vs 0.05% appearance rate
static func determine_pack_type(set_code: String, pull_rates_db: Dictionary) -> String:
	if not pull_rates_db.has(set_code):
		return "Regular Pack"
		
	var set_rates = pull_rates_db[set_code]
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if set_rates.has("Rare Pack"):
		var rare_chance = float(set_rates["Rare Pack"]["appearance_rate"])
		# Roll between 0.0 and 100.0 (e.g., 0.05 is 0.05%)
		var pack_roll = rng.randf_range(0.0, 100.0)
		if pack_roll <= rare_chance:
			return "Rare Pack"
			
	return "Regular Pack"

# STEP 2: Generate the cards strictly using the provided pack_type
static func generate_pack(master_db: Dictionary, selected_pack_id: String, pack_config: Dictionary, pull_rates_db: Dictionary, pack_type: String) -> Array[String]:
	var rolled_pack: Array[String] = []
	
	var p_conf = pack_config[selected_pack_id]
	var set_code = p_conf["set_code"]
	var pack_name = p_conf["pack_name"]
	var card_count = int(p_conf.get("card_count", 5))
	
	var eligible_cards: Dictionary = {}
	
# LEVEL 1: Map the eligible cards based on Set and Pack Name
	for card_id in master_db.keys():
		var c = master_db[card_id]
		
		# SMART ADAPTER: Case-insensitive match prevents A1a vs A1A crashes
		var is_match = (c["set"].to_upper() == set_code.to_upper()) or (set_code == "PROMO" and c["set"].to_upper().begins_with("PROMO"))
		
		if is_match:
			if set_code == "PROMO" or pack_name in c["packs"] or c["packs"].is_empty():
				var r = c["rarity"]
				if not eligible_cards.has(r): eligible_cards[r] = []
				eligible_cards[r].append(card_id)
				
	# LEVEL 2: Fallback if datamine is missing specific pack mappings
	if eligible_cards.is_empty():
		for card_id in master_db.keys():
			var c = master_db[card_id]
			
			# Applied the exact same case-insensitive match here
			var is_match = (c["set"].to_upper() == set_code.to_upper()) or (set_code == "PROMO" and c["set"].to_upper().begins_with("PROMO"))
			
			if is_match:
				var r = c["rarity"]
				if not eligible_cards.has(r): eligible_cards[r] = []
				eligible_cards[r].append(card_id)

	if not pull_rates_db.has(set_code):
		return _fallback_random(eligible_cards, card_count)
		
	var set_rates = pull_rates_db[set_code]
	
	if not set_rates.has(pack_type):
		pack_type = "Regular Pack"
		
	var pack_def = set_rates[pack_type]
	var slots = pack_def["slots"]
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(1, card_count + 1):
		var slot_key = str(i)
		if not slots.has(slot_key): continue
			
		var slot_weights = slots[slot_key]
		var rarity_roll = rng.randf_range(0.0, 100.0)
		var cumulative = 0.0
		var chosen_rarity = ""
		
		for r_key in slot_weights.keys():
			cumulative += float(slot_weights[r_key])
			if rarity_roll <= cumulative:
				chosen_rarity = r_key
				break
				
		if chosen_rarity == "" and slot_weights.size() > 0:
			chosen_rarity = slot_weights.keys()[-1]
			
		if eligible_cards.has(chosen_rarity) and eligible_cards[chosen_rarity].size() > 0:
			var random_card = eligible_cards[chosen_rarity].pick_random()
			rolled_pack.append(random_card)
		else:
			rolled_pack.append(_get_any_valid_card(eligible_cards))
			
	return rolled_pack
	
static func _fallback_random(eligible_cards: Dictionary, count: int) -> Array[String]:
	var fallback: Array[String] = []
	for i in range(count):
		fallback.append(_get_any_valid_card(eligible_cards))
	return fallback

static func _get_any_valid_card(eligible_cards: Dictionary) -> String:
	var all_valid = []
	for pool in eligible_cards.values():
		all_valid.append_array(pool)
	if all_valid.size() > 0:
		return all_valid.pick_random()
	return "UNKNOWN_CARD"
