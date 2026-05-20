extends Node
class_name CardViewModel

const StatTypes = preload("res://scripts/core/stats/StatTypes.gd")

static func normalize_from_payload(payload: Dictionary) -> Dictionary:
	# Accept either a gameplay payload dictionary or an empty/partial map.
	if payload == null or payload.size() == 0:
		return {
			"is_empty": true,
			"display_name": "",
			"description": "",
			"description_short": "",
			"icon": null,
			"category": "",
			"stat_key": "",
			"stat_label": "",
			"base_damage": 0,
			"damage_scaling": 1.0,
			"range": 0,
			"cooldown": 0,
			"cooldown_remaining": 0,
			"is_playable": false,
			"is_usable": false,
			"playability_reason": null,
			"playability_reason_readable": "",
			"state": "empty",
			"cooldown_text": "",
			"state_text": "",
			"stats_summary": "",
			"effects_summary": "",
			"original_payload": payload
		}

	var card_ref = payload.get("card", null)

	var display_name = ""
	if payload.has("display_name"):
		display_name = str(payload.get("display_name"))
	elif payload.has("name"):
		display_name = str(payload.get("name"))
	elif card_ref != null:
		display_name = str(card_ref.display_name)
	else:
		display_name = "Card"

	var description = ""
	if payload.has("description"):
		description = str(payload.get("description"))
	elif card_ref != null:
		description = str(card_ref.description)

	var icon = null
	if payload.has("icon"):
		icon = payload.get("icon")
	elif card_ref != null:
		icon = card_ref.icon

	var stat_key = ""
	if payload.has("scaling_stat"):
		stat_key = str(payload.get("scaling_stat"))
	elif payload.has("stat"):
		stat_key = str(payload.get("stat"))
	elif card_ref != null:
		stat_key = str(card_ref.stat_key)

	var stat_label = ""
	if stat_key != "":
		stat_label = StatTypes.get_label(stat_key)

	var base_dmg = 0
	if payload.has("base_damage"):
		base_dmg = int(payload.get("base_damage"))
	elif card_ref != null:
		base_dmg = int(card_ref.base_damage)

	var scaling = 1.0
	if payload.has("damage_scaling"):
		scaling = float(payload.get("damage_scaling"))
	elif card_ref != null:
		scaling = float(card_ref.damage_scaling)

	var range_val = 0
	if payload.has("range"):
		range_val = int(payload.get("range"))
	elif card_ref != null:
		range_val = int(card_ref.range)

	var cd = 0
	if payload.has("cooldown"):
		cd = int(payload.get("cooldown"))
	elif card_ref != null:
		cd = int(card_ref.cooldown)

	var cd_remaining = 0
	if payload.has("cooldown_remaining"):
		cd_remaining = int(payload.get("cooldown_remaining"))
	elif payload.has("cooldown_remain"):
		cd_remaining = int(payload.get("cooldown_remain"))

	# Playability: prefer explicit full_playable, fall back to cooldown check or legacy is_usable
	var is_playable = false
	if payload.has("full_playable"):
		is_playable = bool(payload.get("full_playable"))
	elif payload.has("cooldown_ok"):
		is_playable = bool(payload.get("cooldown_ok"))
	elif payload.has("is_usable"):
		is_playable = bool(payload.get("is_usable"))
	else:
		is_playable = cd_remaining <= 0

	var is_usable = bool(payload.get("is_usable", is_playable))
	var playability_reason = payload.get("playability_reason", null)
	var playability_reason_readable = str(payload.get("playability_reason_readable", ""))

	var cooldown_text = ""
	if cd_remaining > 0:
		cooldown_text = "CD: %d" % cd_remaining

	var state_text = ""
	if is_playable and cd_remaining <= 0:
		state_text = "Disponible"
	elif cd_remaining > 0:
		state_text = "En enfriamiento (%d)" % cd_remaining
	elif not is_playable:
		state_text = str(payload.get("state", "Bloqueada")).capitalize()

	var stats_summary = "%s x%.2f | D:%d | R:%d | CD:%d" % [stat_label, scaling, base_dmg, range_val, cd]

	# Effects summary: try payload.effects or card_ref.effects
	var effects_arr := []
	if payload.has("effects") and typeof(payload.get("effects")) == TYPE_ARRAY:
		effects_arr = payload.get("effects")
	elif card_ref != null:
		effects_arr = card_ref.effects

	var effects_texts := []
	for e in effects_arr:
		if e == null:
			continue
		var desc := ""
		if typeof(e) == TYPE_DICTIONARY:
			desc = str(e.get("description", ""))
		else:
			# Prefer effect description APIs on CardEffect resources.
			if e is CardEffect:
				desc = str(e.get_description())
			elif typeof(e) == TYPE_OBJECT:
				var candidate = e.get("description")
				if candidate != null and str(candidate) != "":
					desc = str(candidate)
				else:
					var s = str(e)
					if s != "" and not (s.begins_with("res://") or s.begins_with("user://")):
						desc = s
		if desc != "":
			effects_texts.append(desc)

	var effects_summary = ""
	if effects_texts.size() > 0:
		effects_summary = ", ".join(effects_texts)

	return {
		"is_empty": false,
		"display_name": display_name,
		"description": description,
		"description_short": description.substr(0, 200) if description.length() > 200 else description,
		"icon": icon,
		"category": (str(payload.get("category")) if payload.has("category") else (str(card_ref.category) if card_ref != null else "")),
		"stat_key": stat_key,
		"stat_label": stat_label,
		"base_damage": base_dmg,
		"damage_scaling": scaling,
		"range": range_val,
		"cooldown": cd,
		"cooldown_remaining": cd_remaining,
		"is_playable": is_playable,
		"is_usable": is_usable,
		"playability_reason": playability_reason,
		"playability_reason_readable": playability_reason_readable,
		"state": payload.get("state", ""),
		"cooldown_text": cooldown_text,
		"state_text": state_text,
		"stats_summary": stats_summary,
		"effects_summary": effects_summary,
		"original_payload": payload,
		"card_ref": card_ref
	}

static func from_card(card: Resource) -> Dictionary:
	if card == null:
		return normalize_from_payload({})
	var p := {
		"card": card,
		"display_name": card.display_name,
		"description": card.description,
		"icon": card.icon,
		"stat": card.stat_key,
		"scaling_stat": card.stat_key,
		"damage_scaling": card.damage_scaling,
		"base_damage": card.base_damage,
		"range": card.range,
		"cooldown": card.cooldown,
		"effects": card.effects,
		"category": card.category
	}
	return normalize_from_payload(p)
