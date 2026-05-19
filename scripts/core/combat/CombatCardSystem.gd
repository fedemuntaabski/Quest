extends Node
class_name CombatCardSystem

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

func get_card_validation(card: CardData, target: Node) -> Dictionary:
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
		var target_component := _resolve_target_component(target)
		if target_component == null:
			result["reason"] = "no_target"
			return result
		if target_component.stats == null:
			result["reason"] = "missing_target_stats"
			return result
		if not target_component.stats.is_alive():
			result["reason"] = "target_dead"
			return result

	if card.target_type == "self" and not combat_component.stats.is_alive():
		result["reason"] = "source_dead"
		return result

	result["valid"] = true
	result["reason"] = "ok"
	return result

func can_play(card: CardData, target: Node) -> bool:
	return bool(get_card_validation(card, target).get("valid", false))

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

	# Explicitly repair target room/occupancy before snapshotting
	if map_manager and map_manager.core:
		map_manager.core.repair_actor_room(target)

	var occ_ver := -1
	if map_manager and map_manager.occupancy_manager:
		occ_ver = map_manager.occupancy_manager.get_version()

	var snapshot := {
		"target": target,
		"cell": map_manager.get_actor_cell(target) if map_manager else null,
		"room_id": map_manager.get_actor_room_id(target) if map_manager else -1,
		"occ_version": occ_ver
	}

	var action := CardAction.new(self, card, snapshot)
	turn_manager.action_queue.queue_action(action)
	return true

func execute_card(card: CardData, target: Node) -> Dictionary:
	var validation := get_card_validation(card, target)
	if not bool(validation.get("valid", false)):
		var reason := str(validation.get("reason", "invalid"))
		card_failed.emit(card, reason)
		return {"hit": false, "damage": 0, "reason": reason}

	var target_component := _resolve_target_component(target)
	if target_component == null or target_component.stats == null:
		card_failed.emit(card, "no_target")
		return {"hit": false, "damage": 0, "reason": "no_target"}

	var result := CardResolver.resolve_card(card, combat_component.stats, target_component.stats)
	if owner_actor and owner_actor.is_in_group("player"):
		var hud := get_tree().get_first_node_in_group("hud") as HUDController
		if hud:
			hud.set_roll_label_from_result(result)

	var damage := int(result.get("damage", 0))
	if result.get("hit", false) and damage > 0:
		target_component.receive_damage(damage, result.get("crit", false))
	elif not result.get("hit", false) and target_component.actor_owner and target_component.actor_owner.has_method("show_miss"):
		target_component.actor_owner.show_miss()

	# Apply runtime effects via EffectApplier to centralize map/status interactions
	# Defensive: ensure map_manager and target actor are valid before applying effects
	if map_manager == null:
		push_warning("CombatCardSystem.execute_card: missing map_manager, skipping runtime effects")
	else:
		if target_component.actor_owner == null or not is_instance_valid(target_component.actor_owner):
			push_warning("CombatCardSystem.execute_card: target actor invalid, skipping runtime effects")
		else:
			var ctx := EffectContext.new(owner_actor, map_manager, card_manager, combat_component)
			var applier := EffectApplier.new()
			await applier.apply(result, target_component, ctx)

	card_manager.start_cooldown(card)
	card_played.emit(card, target, result)
	if owner_actor and owner_actor.is_in_group("player") and card_manager:
		card_manager.set_active_index(-1)
	return result


func execute_card_snapshot(card: CardData, snapshot: Dictionary) -> Dictionary:
	# Snapshot-aware execution: validate occupancy version and avoid re-repairing
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
			card_failed.emit(card, "stale_snapshot")
			return {"hit": false, "damage": 0, "reason": "stale_snapshot", "stale": true}

	# Use resolved target component without re-repair
	var target_component := _resolve_target_component(target)
	if target_component == null or target_component.stats == null:
		card_failed.emit(card, "no_target_component")
		return {"hit": false, "damage": 0, "reason": "no_target_component"}

	var validation := get_card_validation(card, target)
	if not bool(validation.get("valid", false)):
		var reason := str(validation.get("reason", "invalid"))
		card_failed.emit(card, reason)
		return {"hit": false, "damage": 0, "reason": reason}

	var result := CardResolver.resolve_card(card, combat_component.stats, target_component.stats)
	if owner_actor and owner_actor.is_in_group("player"):
		var hud := get_tree().get_first_node_in_group("hud") as HUDController
		if hud:
			hud.set_roll_label_from_result(result)

	var damage := int(result.get("damage", 0))
	if result.get("hit", false) and damage > 0:
		target_component.receive_damage(damage, result.get("crit", false))
	elif not result.get("hit", false) and target_component.actor_owner and target_component.actor_owner.has_method("show_miss"):
		target_component.actor_owner.show_miss()

	if map_manager == null:
		push_warning("CombatCardSystem.execute_card_snapshot: missing map_manager, skipping runtime effects")
	else:
		if target_component.actor_owner == null or not is_instance_valid(target_component.actor_owner):
			push_warning("CombatCardSystem.execute_card_snapshot: target actor invalid, skipping runtime effects")
		else:
			var ctx := EffectContext.new(owner_actor, map_manager, card_manager, combat_component)
			var applier := EffectApplier.new()
			await applier.apply(result, target_component, ctx)

	card_manager.start_cooldown(card)
	card_played.emit(card, target, result)
	if owner_actor and owner_actor.is_in_group("player") and card_manager:
		card_manager.set_active_index(-1)
	return result

## Runtime application moved to EffectApplier.gd (EffectContext)

func _resolve_movement_direction(receiver: Node, reference: Node, movement_mode: String) -> Vector2i:
	var receiver_cell: Vector2i = CardTargeting.get_actor_cell(receiver, map_manager)
	if receiver_cell == null:
		return Vector2i.ZERO

	var destination: Vector2i = _get_hover_or_reference_cell(reference)
	if destination == null:
		return Vector2i.ZERO

	var delta: Vector2i = destination - receiver_cell
	var direction := Vector2i(signi(delta.x), signi(delta.y))

	match movement_mode:
		"pull":
			return -direction
		"knockback":
			return -direction
		_:
			return direction

func _get_hover_or_reference_cell(reference: Node) -> Variant:
	if map_manager and map_manager.hovered_cell != Vector2i(-999, -999):
		return map_manager.hovered_cell
	if reference:
		return CardTargeting.get_actor_cell(reference, map_manager)
	return null

func _resolve_target_component(target: Node) -> CombatComponent:
	if target == null:
		return null
	if target is CombatComponent:
		return target
	if target.has_method("get_combat_component"):
		return target.get_combat_component() as CombatComponent
	return target.get_node_or_null("CombatComponent") as CombatComponent
