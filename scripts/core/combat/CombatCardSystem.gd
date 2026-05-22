extends Node
class_name CombatCardSystem

# CombatCardSystem: per-actor coordinator responsible for validating,
# queuing, executing and finalizing card plays. It delegates target validation
# and damage resolution to `CombatValidation` and `CombatResolver` respectively,
# and delegates runtime effect application to `EffectApplier`/`EffectContext`.

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
				print("[CombatCardSystem] card validation rejected due to not_in_same_room; allowing for cards by default")
			if val.has("distance"):
				result["distance"] = val.get("distance")
			if val.has("max_range"):
				result["max_range"] = val.get("max_range")
			return result

	if card.target_type == "self":
		if not combat_component.stats.is_alive():
			result["reason"] = "source_dead"
			return result

	result["valid"] = true
	result["reason"] = "ok"
	result["distance"] = _get_card_distance(card, target)
	return result


func get_card_validation(card: CardData, target: Node) -> Dictionary:
	# Public wrapper kept for compatibility. Internally delegates to
	# _compute_card_validation so future callers in this file can reuse the
	# internal helper and we have a single place to extend validation behaviour.
	return _compute_card_validation(card, target)


func can_play(card: CardData, target: Node) -> bool:
	return bool(get_card_validation(card, target).get("valid", false))


func _get_card_distance(card: CardData, target: Node) -> int:
	# Returns distance from owner to target (Chebyshev distance)
	if card == null or target == null or owner_actor == null:
		return -1
	var owner_cell : Variant = CardTargeting.get_actor_cell(owner_actor, map_manager)
	var target_cell : Variant = CardTargeting.get_actor_cell(target, map_manager)
	if owner_cell == null or target_cell == null:
		return -1
	return CardTargeting.get_chebyshev_distance(owner_cell, target_cell)


func queue_card_action(card: CardData, target: Node, turn_manager: TurnManager) -> bool:
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
		print("[CombatCardSystem] Queue card '%s' at distance %d / range %d" % [card.display_name, distance, card.range])

	var occ_ver := -1
	if map_manager and map_manager.occupancy_manager:
		occ_ver = map_manager.occupancy_manager.get_version()

	var snapshot := {
		"target": target,
		"cell": map_manager.get_actor_cell(target) if map_manager else null,
		"room_id": map_manager.get_actor_room_id(target) if map_manager else -1,
		"occ_version": occ_ver
	}

	var action = CardAction.new(self, card, snapshot)
	turn_manager.action_queue.queue_action(action)
	return true

func execute_card(card: CardData, target: Node) -> Dictionary:
	var validation := get_card_validation(card, target)
	if not bool(validation.get("valid", false)):
		var reason := str(validation.get("reason", "invalid"))
		card_failed.emit(card, reason)
		return {"hit": false, "damage": 0, "reason": reason}
	var target_component: CombatComponent = CombatValidation.resolve_target_component(target)
	if target_component == null or target_component.stats == null:
		card_failed.emit(card, "no_target")
		return {"hit": false, "damage": 0, "reason": "no_target"}

	var result := CardResolver.resolve_card(card, combat_component.stats, target_component.stats)
	return await _finalize_card_execution(card, target, target_component, result)
	return await _finalize_card_execution(card, target, target_component, result)


func execute_card_snapshot(card: CardData, snapshot: Dictionary) -> Dictionary:
	# Snapshot-aware execution: validate occupancy version and avoid re-repairing
	print("[CombatCardSystem] execute_card_snapshot: START card=", card.display_name if card else "NULL", " snapshot=", snapshot)
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
			var live_val := get_card_validation(card, target)
			if not bool(live_val.get("valid", false)):
				card_failed.emit(card, "stale_snapshot")
				return {"hit": false, "damage": 0, "reason": "stale_snapshot", "stale": true}
			# else: continue execution using live state

	# Use resolved target component without re-repair
	var target_component: CombatComponent = CombatValidation.resolve_target_component(target)
	if target_component == null or target_component.stats == null:
		card_failed.emit(card, "no_target_component")
		return {"hit": false, "damage": 0, "reason": "no_target_component"}

	var validation := get_card_validation(card, target)
	if not bool(validation.get("valid", false)):
		var reason := str(validation.get("reason", "invalid"))
		card_failed.emit(card, reason)
		return {"hit": false, "damage": 0, "reason": reason}

	var distance := int(validation.get("distance", -1))
	var result := CardResolver.resolve_card(card, combat_component.stats, target_component.stats)
	return await _finalize_card_execution(card, target, target_component, result, int(snapshot.get("occ_version", -1)))


## Runtime application moved to EffectApplier.gd (EffectContext)

func _finalize_card_execution(card: CardData, target: Node, target_component: CombatComponent, result: Dictionary, _occ_version: int = -1) -> Dictionary:
		# Shared finalization logic for card execution paths. Performs HUD update,
		# damage/miss handling, effect application (awaited), cooldown and signal
		# emission, and active_index reset for player-owned actors.
		if owner_actor and owner_actor.is_in_group("player"):
			var hud := get_tree().get_first_node_in_group("hud") as HUDController
			if hud:
				hud.show_combat_result(result)

		var damage := int(result.get("damage", 0))
		# Debug: log finalization info
		if result.get("hit", false) and damage > 0:
			print("[CombatCardSystem] _finalize_card_execution: applying damage=", damage)
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

