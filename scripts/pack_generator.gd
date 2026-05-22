extends Node
class_name PackGenerator

static func generate_pack(master_db: Dictionary, selected_pack_id: String, pack_config: Dictionary, pull_rates_db: Dictionary) -> Array[String]:
	var rolled_pack: Array[String] = []
	
	var p_conf = pack_config[selected_pack_id]
	var set_code = p_conf["set_code"]
	var pack_name = p_conf["pack_name"]
	var card_count = int(p_conf.get("card_count", 5))
	
	var eligible_cards: Dictionary = {}
	
	# LEVEL 1: Try to match the exact Set and Pack Name
	for card_id in master_db.keys():
		var c = master_db[card_id]
		if c["set"] == set_code:
			if pack_name in c["packs"] or c["packs"].is_empty():
				var r = c["rarity"]
				if not eligible_cards.has(r): eligible_cards[r] = []
				eligible_cards[r].append(card_id)
				
	# LEVEL 2: If the datamine is missing pack names, fall back to ANY card in the Set
	if eligible_cards.is_empty():
		print("Warning: No cards matched pack '", pack_name, "'. Falling back to entire Set.")
		for card_id in master_db.keys():
			var c = master_db[card_id]
			if c["set"] == set_code:
				var r = c["rarity"]
				if not eligible_cards.has(r): eligible_cards[r] = []
				eligible_cards[r].append(card_id)
				
	# LEVEL 3: If the Set is entirely empty/unmapped, fall back to the ENTIRE game
	if eligible_cards.is_empty():
		print("Critical: Set '", set_code, "' is empty! Falling back to global database.")
		for card_id in master_db.keys():
			var r = master_db[card_id]["rarity"]
			if not eligible_cards.has(r): eligible_cards[r] = []
			eligible_cards[r].append(card_id)
			
	if not pull_rates_db.has(set_code):
		print("Warning: No pull rates mapped for set ", set_code, " - Using random fallback.")
		return _fallback_random(eligible_cards, card_count)
		
	var set_rates = pull_rates_db[set_code]
	
	var is_rare_pack = false
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	if set_rates.has("Rare Pack"):
		var rare_chance = float(set_rates["Rare Pack"]["appearance_rate"])
		var pack_roll = rng.randf_range(0.0, 100.0)
		if pack_roll <= rare_chance:
			is_rare_pack = true
			
	var pack_type_key = "Rare Pack" if is_rare_pack else "Regular Pack"
	var pack_def = set_rates[pack_type_key]
	var slots = pack_def["slots"]
	
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
			var any_valid_card = _get_any_valid_card(eligible_cards)
			rolled_pack.append(any_valid_card)
			
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
