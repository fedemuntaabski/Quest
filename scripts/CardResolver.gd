extends RefCounted
class_name CardResolver

const CombatResolverScript = preload("res://scripts/CombatResolver.gd")
const DamageEffect = preload("res://scripts/DamageEffect.gd")
const StatModifierEffect = preload("res://scripts/StatModifierEffect.gd")

static func resolve_card(card: CardData, source_stats: CharacterStats, target_stats: CharacterStats) -> Dictionary:
	var results: Array = []
	var has_damage := false

	if card == null or source_stats == null or target_stats == null:
		return {"results": results, "hit": false, "damage": 0}

	if card.effects.is_empty():
		var damage_result := _resolve_damage(card.stat_key, card.base_damage, card.damage_scaling, source_stats, target_stats)
		results.append(damage_result)
		has_damage = true
	else:
		for effect in card.effects:
			if effect is DamageEffect:
				var dmg: DamageEffect = effect
				var damage_result := _resolve_damage(dmg.stat_key, dmg.base_damage, dmg.damage_scaling, source_stats, target_stats)
				results.append(damage_result)
				has_damage = true
			elif effect is StatModifierEffect:
				var mod: StatModifierEffect = effect
				var mod_result := _apply_stat_modifier(mod, target_stats)
				results.append(mod_result)

	var summary := _summarize_results(results)
	if not has_damage:
		summary["hit"] = true

	return summary

static func _resolve_damage(stat_key: String, base_damage: int, scaling: float, source_stats: CharacterStats, target_stats: CharacterStats) -> Dictionary:
	var stat_value := _get_stat_value(source_stats, stat_key)
	var scaled_bonus := int(round(float(stat_value) * scaling))
	return CombatResolverScript.resolve_attack(
		source_stats,
		target_stats,
		stat_key,
		base_damage + scaled_bonus
	)

static func _apply_stat_modifier(effect: StatModifierEffect, target_stats: CharacterStats) -> Dictionary:
	if target_stats:
		target_stats.apply_modifier(effect.stat_key, effect.value)
	return {
		"effect": "stat_modifier",
		"stat_key": effect.stat_key,
		"value": effect.value,
		"duration": effect.duration_turns
	}

static func _summarize_results(results: Array) -> Dictionary:
	var summary := {
		"results": results,
		"hit": false,
		"crit": false,
		"damage": 0
	}

	for item in results:
		if item.has("hit"):
			summary["hit"] = summary["hit"] or item.get("hit", false)
			summary["crit"] = summary["crit"] or item.get("crit", false)
			summary["damage"] += int(item.get("damage", 0))
	return summary

static func _get_stat_value(stats: CharacterStats, stat_key: String) -> int:
	match stat_key:
		"strength":
			return stats.get_total_strength()
		"magic":
			return stats.get_total_magic()
		"dexterity":
			return stats.get_total_dexterity()
		_:
			return stats.get_total_strength()
