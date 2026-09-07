extends Node
class_name CombatCardSystem

const PRELOAD_DAMAGE_EFFECT = preload("res://scripts/core/effects/DamageEffect.gd")
const ARCANE_MARK_STATUS_ID := "arcane_mark"
const ARCANE_MARK_BONUS_DAMAGE := 2

# CombatCardSystem: per-actor coordinator responsible for validating,
# queuing, executing and finalizing card plays.
# Responsibilities:
# - Public API: `get_card_validation`, `can_play`, `queue_card_action`.
# - Snapshot-aware execution via `execute_card_snapshot` to avoid stale
#   occupancy races; verifies `occ_version` then resolves and finalizes
#   effects through `EffectApplier` and `EffectContext`.
# Signals:
# - `card_played(card, target, result)` emitted after successful execution.
# - `card_failed(card, reason)` emitted for user-visible rejections.

signal card_played(card: CardData, target: Node, result: Dictionary)
signal card_failed(card: CardData, reason: String)

var owner_actor: Node = null
var map_manager: MapManager = null
var card_manager: CardManager = null
var combat_component: CombatComponent = null

func setup(p_owner: Node, p_map: MapManager, p_card_manager: CardManager, p_combat: CombatComponent) -> void:
	owner_actor = p_owner
	map_manager = p_map
	card_manager = p_card_manager
	combat_component = p_combat
	add_to_group("combat_card_system")

	# Note: `setup` is expected to be called once during actor initialization.
	# The system intentionally does not mutate card_manager state directly;
	# ownership of decks/cooldowns remains with CardManager.

func _compute_card_validation(card: CardData, target: Node) -> Dictionary:
	# Internal consolidated validator. Keep logic identical to the previous
	# public implementation to preserve runtime behaviour. External callers
	# should continue to use get_card_validation() which wraps this helper.
	var result := {
		"valid": false,
		"reason": "invalid"
	}

	if card == null:
		result["reason"] = "missing_card"
		return result
	if card_manager == null:
		result["reason"] = "missing_card_manager"
		return result
	if combat_component == null:
		result["reason"] = "missing_combat_component"
		return result
	if combat_component.stats == null:
		result["reason"] = "missing_stats"
		return result
	if not card_manager.can_play_card(card):
		result["reason"] = "card_on_cooldown"
		return result

	if card.target_type == "enemy":
		# Delegate target validation but do NOT enforce room engagement here
		# (cards historically only enforced range/alive checks). Keep
		# `check_engagement=false` to preserve previous card behavior.
		var val := CombatValidation.validate_target(combat_component, target, map_manager, card.range, true, false)
		if not bool(val.get("valid", false)):
			# Preserve reason and distance/max_range fields for compatibility
			result["reason"] = str(val.get("reason", "invalid"))
			# Helpful debug for common validation failures
			if result["reason"] == "not_in_same_room":
				Logger.debug(Logger.Category.CARDS, "card validation rejected due to not_in_same_room; allowing for cards by default")
			if val.has("distance"):
				result["distance"] = val.get("distance")
			if val.has("max_range"):
				result["max_range"] = val.get("max_range")
			return result

	if card.target_type == "self":
		if not combat_component.stats.is_alive():
			result["reason"] = "source_dead"
			return result

	if card.targeting_profile == "dash":
		return _validate_dash_destination(card, map_manager.hovered_cell if map_manager else Vector2i(-999, -999))

	result["valid"] = true
	result["reason"] = "ok"
	var owner_cell : Variant = CardTargeting.get_actor_cell(owner_actor, map_manager)
	var target_cell : Variant = CardTargeting.get_actor_cell(target, map_manager)
	if owner_cell == null or target_cell == null:
		result["distance"] = -1
	else:
		result["distance"] = CardTargeting.get_chebyshev_distance(owner_cell, target_cell)
	return result


func get_card_validation(card: CardData, target: Node) -> Dictionary:
	# Public wrapper kept for compatibility. Internally delegates to
	# _compute_card_validation so future callers in this file can reuse the
	# internal helper and we have a single place to extend validation behaviour.
	return _compute_card_validation(card, target)

func validate_card_snapshot(card: CardData, snapshot: Dictionary) -> Dictionary:
	if card == null:
		return {"valid": false, "reason": "missing_card"}
	if card.targeting_profile != "dash":
		return get_card_validation(card, snapshot.get("target", null) as Node)
	var destination_cell: Variant = snapshot.get("destination_cell", Vector2i(-999, -999))
	return _validate_dash_destination(card, destination_cell)

func _validate_dash_destination(card: CardData, destination_cell: Variant) -> Dictionary:
	var result := {
		"valid": false,
		"reason": "invalid"
	}
	if card == null:
		result["reason"] = "missing_card"
		return result
	if owner_actor == null or map_manager == null:
		result["reason"] = "missing_destination"
		return result
	if destination_cell == null or destination_cell == Vector2i(-999, -999):
		result["reason"] = "invalid_destination"
		return result

	var source_cell = CardTargeting.get_actor_cell(owner_actor, map_manager)
	if source_cell == null:
		result["reason"] = "invalid_destination"
		return result
	if destination_cell == source_cell:
		result["reason"] = "invalid_destination"
		return result
	if CardTargeting.get_chebyshev_distance(source_cell, destination_cell) > card.range:
		result["reason"] = "out_of_range"
		result["distance"] = CardTargeting.get_chebyshev_distance(source_cell, destination_cell)
		result["max_range"] = card.range
		return result
	if not map_manager.is_walkable_cell_for_actor(destination_cell, owner_actor):
		result["reason"] = "invalid_destination"
		return result
	var path := map_manager.find_path(source_cell, destination_cell, owner_actor)
	if path.is_empty() or path.size() - 1 > card.range:
		result["reason"] = "invalid_destination"
		return result

	result["valid"] = true
	result["reason"] = "ok"
	result["distance"] = CardTargeting.get_chebyshev_distance(source_cell, destination_cell)
	result["destination_cell"] = destination_cell
	return result


func queue_card_action(card: CardData, target: Node, turn_manager: TurnManager, extra_snapshot: Dictionary = {}) -> bool:
	if card == null:
		card_failed.emit(card, "missing_card")
		return false
	if turn_manager == null:
		card_failed.emit(card, "no_turn_manager")
		return false
	if turn_manager.action_queue == null:
		card_failed.emit(card, "no_action_queue")
		return false
	if turn_manager.action_queue.is_busy():
		card_failed.emit(card, "queue_busy")
		return false
	var validation := get_card_validation(card, target)
	if not bool(validation.get("valid", false)):
		card_failed.emit(card, str(validation.get("reason", "invalid")))
		return false

	var distance := int(validation.get("distance", -1))
	if card.target_type == "enemy":
		Logger.info(Logger.Category.CARDS, "Queue card '%s' at distance %d / range %d" % [card.display_name, distance, card.range])

	var occ_ver := -1
	if map_manager and map_manager.occupancy_manager:
		occ_ver = map_manager.occupancy_manager.get_version()

	var snapshot := {
		"target": target,
		"cell": map_manager.get_actor_cell(target) if map_manager else null,
		"room_id": map_manager.get_actor_room_id(target) if map_manager else -1,
		"occ_version": occ_ver
	}
	for key in extra_snapshot.keys():
		snapshot[key] = extra_snapshot[key]

	var action = CardAction.new(self, card, snapshot)
	turn_manager.action_queue.queue_action(action)
	return true

func execute_card(card: CardData, target: Node) -> Dictionary:
	return await execute_card_snapshot(card, {"target": target})

func execute_card_snapshot(card: CardData, snapshot: Dictionary) -> Dictionary:
	# Snapshot-aware execution: validate occupancy version and avoid re-repairing
	Logger.debug(Logger.Category.CARDS, "execute_card_snapshot: START card=%s snapshot=%s" % [card.display_name if card else "NULL", str(snapshot)])
	if card == null:
		card_failed.emit(card, "missing_card")
		return {"hit": false, "damage": 0, "reason": "missing_card"}

	var target: Node = snapshot.get("target", null)
	if target == null:
		card_failed.emit(card, "no_target")
		return {"hit": false, "damage": 0, "reason": "no_target"}

	# Check occupancy version
	if map_manager and map_manager.occupancy_manager:
		var current_ver := map_manager.occupancy_manager.get_version()
		var snap_ver := int(snapshot.get("occ_version", -1))
		if snap_ver != -1 and snap_ver != current_ver:
			# Try a live re-validation: if the live state still allows the play,
			# proceed; otherwise fail with stale_snapshot. This avoids brittle
			# failures when occupancy changed but target is still valid.
			var live_val := validate_card_snapshot(card, snapshot) if card.targeting_profile == "dash" else get_card_validation(card, target)
			if not bool(live_val.get("valid", false)):
				card_failed.emit(card, "stale_snapshot")
				return {"hit": false, "damage": 0, "reason": "stale_snapshot", "stale": true}
			# else: continue execution using live state

	# Use resolved target component without re-repair
	var target_component: CombatComponent = CombatValidation.resolve_target_component(target)
	if target_component == null or target_component.stats == null:
		card_failed.emit(card, "no_target_component")
		return {"hit": false, "damage": 0, "reason": "no_target_component"}

	var validation := validate_card_snapshot(card, snapshot) if card.targeting_profile == "dash" else get_card_validation(card, target)
	if not bool(validation.get("valid", false)):
		var reason := str(validation.get("reason", "invalid"))
		card_failed.emit(card, reason)
		return {"hit": false, "damage": 0, "reason": reason}
	var result := _resolve_card_result(card, combat_component.stats, target_component.stats, target_component.actor_owner)
	return await _finalize_card_execution(card, target, target_component, result, snapshot, int(snapshot.get("occ_version", -1)))


## Runtime application moved to EffectApplier.gd (EffectContext)

func _finalize_card_execution(card: CardData, target: Node, target_component: CombatComponent, result: Dictionary, snapshot: Dictionary, _occ_version: int = -1) -> Dictionary:
		# Shared finalization logic for card execution paths. Performs HUD update,
		# damage/miss handling, effect application (awaited), cooldown and signal
		# emission, and active_index reset for player-owned actors.
		_apply_arcane_mark_bonus(card, target_component, result)

		if owner_actor and owner_actor.is_in_group("player"):
			var hud := get_tree().get_first_node_in_group("hud") as HUDController
			if hud:
				hud.show_combat_result(result)

		var damage := int(result.get("damage", 0))
		if result.get("hit", false) and damage > 0:
			Logger.debug(Logger.Category.COMBAT, "_finalize_card_execution: applying damage=%d" % damage)
			target_component.receive_damage(damage, result.get("crit", false))
		elif not result.get("hit", false) and target_component.actor_owner and target_component.actor_owner.has_method("show_miss"):
			target_component.actor_owner.show_miss()

		if map_manager == null:
			push_warning("CombatCardSystem._finalize_card_execution: missing map_manager, skipping runtime effects")
		else:
			if target_component.actor_owner == null or not is_instance_valid(target_component.actor_owner):
				push_warning("CombatCardSystem._finalize_card_execution: target actor invalid, skipping runtime effects")
			else:
				var ctx := EffectContext.new(owner_actor, map_manager, card_manager, combat_component)
				ctx.extra["destination_cell"] = snapshot.get("destination_cell", null)
				ctx.extra["target_actor"] = target_component.actor_owner
				var applier := EffectApplier.new()
				await applier.apply(result, target_component, ctx)

		card_manager.start_cooldown(card)
		card_played.emit(card, target, result)
		if owner_actor and owner_actor.is_in_group("player") and card_manager:
			# Prefer CardSystemController as the canonical external writer for selection
			var controller := owner_actor.get_node_or_null("CardSystemController") as CardSystemController
			if controller != null:
				controller.request_set_active_index(-1)
			else:
				card_manager.set_active_index(-1)
		return result

func _apply_arcane_mark_bonus(card: CardData, target_component: CombatComponent, result: Dictionary) -> void:
	if card == null or target_component == null or result == null:
		return
	if not bool(result.get("hit", false)):
		return
	if int(result.get("damage", 0)) <= 0:
		return
	if not _is_arcane_projectile_card(card):
		return

	var target_actor := target_component.actor_owner
	if target_actor == null:
		return

	var status_component := target_actor.get_node_or_null("StatusComponent") as StatusComponent
	if status_component == null:
		return
	if not status_component.has_status(ARCANE_MARK_STATUS_ID):
		return

	result["damage"] = int(result.get("damage", 0)) + ARCANE_MARK_BONUS_DAMAGE
	status_component.remove_status(ARCANE_MARK_STATUS_ID)

func _is_arcane_projectile_card(card: CardData) -> bool:
	if card == null:
		return false

	var combined_tags: Array[String] = []
	for raw_tag in card.tags:
		combined_tags.append(str(raw_tag).to_lower())
	for raw_combo_tag in card.combo_tags:
		combined_tags.append(str(raw_combo_tag).to_lower())

	return combined_tags.has("arcane_projectile") or combined_tags.has("arcane")

func _resolve_card_result(card: CardData, source_stats: CharacterStats, target_stats: CharacterStats, target_actor: Node = null) -> Dictionary:
	var results: Array = []
	var has_damage := false
	Logger.debug(Logger.Category.COMBAT, "resolve_card: START card=%s effects=%d" % [card.display_name if card else "NULL", card.effects.size() if card else 0])

	if card == null or source_stats == null or target_stats == null:
		Logger.warn(Logger.Category.COMBAT, "resolve_card: reject reason=missing_inputs")
		return {"results": results, "hit": false, "damage": 0}

	if card.effects.is_empty():
		var fallback_damage := PRELOAD_DAMAGE_EFFECT.new()
		fallback_damage.base_damage = card.base_damage
		fallback_damage.stat_key = card.stat_key
		fallback_damage.damage_scaling = card.damage_scaling
		var damage_result := fallback_damage.apply(source_stats, target_stats, {"card": card, "target_actor": target_actor})
		results.append(damage_result)
		has_damage = true
	else:
		for effect in card.effects:
			if effect == null:
				continue
			if not effect.has_method("apply"):
				continue
			var effect_result: Variant = effect.apply(source_stats, target_stats, {"card": card, "target_actor": target_actor})
			if effect_result is Dictionary:
				results.append(effect_result)
				if effect is PRELOAD_DAMAGE_EFFECT or str(effect_result.get("effect", "")) == "damage":
					has_damage = true

	var summary := _summarize_card_results(results)
	if not has_damage:
		summary["hit"] = true
	Logger.debug(Logger.Category.COMBAT, "resolve_card: END card=%s hit=%s damage=%d" % [card.display_name, summary.get("hit", false), int(summary.get("damage", 0))])

	return summary

func _summarize_card_results(results: Array) -> Dictionary:
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

