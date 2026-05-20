extends RefCounted
class_name CardResolver

const PRELOAD_DAMAGE_EFFECT = preload("res://scripts/core/effects/DamageEffect.gd")

static func resolve_card(card: CardData, source_stats: CharacterStats, target_stats: CharacterStats) -> Dictionary:
	var results: Array = []
	var has_damage := false
	print("[CardResolver] resolve_card: START card=%s effects=%d" % [card.display_name if card else "NULL", card.effects.size() if card else 0])

	if card == null or source_stats == null or target_stats == null:
		print("[CardResolver] resolve_card: reject reason=missing_inputs card=%s source_stats=%s target_stats=%s" % ["valid" if card else "NULL", "valid" if source_stats else "NULL", "valid" if target_stats else "NULL"])
		return {"results": results, "hit": false, "damage": 0}

	if card.effects.is_empty():
		var fallback_damage := PRELOAD_DAMAGE_EFFECT.new()
		fallback_damage.base_damage = card.base_damage
		fallback_damage.stat_key = card.stat_key
		fallback_damage.damage_scaling = card.damage_scaling
		var damage_result := fallback_damage.apply(source_stats, target_stats, {"card": card})
		results.append(damage_result)
		has_damage = true
	else:
		for effect in card.effects:
			if effect == null:
				continue
			if not effect.has_method("apply"):
				continue
			var effect_result: Variant = effect.apply(source_stats, target_stats, {"card": card})
			if effect_result is Dictionary:
				results.append(effect_result)
				if effect is PRELOAD_DAMAGE_EFFECT or str(effect_result.get("effect", "")) == "damage":
					has_damage = true

	var summary := _summarize_results(results)
	if not has_damage:
		summary["hit"] = true
	print("[CardResolver] resolve_card: END card=%s hit=%s damage=%d result_count=%d movement=%d statuses=%d modifiers=%d" % [card.display_name, summary.get("hit", false), int(summary.get("damage", 0)), results.size(), summary.get("movement", []).size(), summary.get("statuses", []).size(), summary.get("modifiers", []).size()])

	return summary

static func _summarize_results(results: Array) -> Dictionary:
	var summary := {
		"results": results,
		"hit": false,
		"crit": false,
		"damage": 0,
		"healing": 0,
		"modifiers": [],
		"movement": [],
		"statuses": []
	}

	for item in results:
		if not (item is Dictionary):
			continue

		var effect_kind := str(item.get("effect", ""))
		if effect_kind == "buff" or effect_kind == "stat_modifier":
			summary["modifiers"].append(item)
		elif effect_kind == "movement":
			summary["movement"].append(item)
		elif effect_kind == "status":
			summary["statuses"].append(item)
		elif effect_kind == "heal":
			summary["healing"] += int(item.get("amount", 0))

		if item.has("hit"):
			summary["hit"] = summary["hit"] or item.get("hit", false)
			summary["crit"] = summary["crit"] or item.get("crit", false)
			summary["damage"] += int(item.get("damage", 0))
	return summary
