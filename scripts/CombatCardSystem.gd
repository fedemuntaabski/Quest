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

func can_play(card: CardData, target: Node) -> bool:
	if card == null or card_manager == null or combat_component == null:
		return false
	if combat_component.stats == null:
		return false
	if not card_manager.can_play_card(card):
		return false
	if not CardTargeting.is_valid_target(card, owner_actor, target, map_manager):
		return false
	if card.target_type == "enemy":
		var target_component := _resolve_target_component(target)
		if target_component == null or target_component.stats == null:
			return false
		if not target_component.stats.is_alive():
			return false
		if not CardTargeting.is_in_range(owner_actor, target, card.range, map_manager):
			return false
	if card.target_type == "self" and combat_component.stats and not combat_component.stats.is_alive():
		return false
	return true

func queue_card_action(card: CardData, target: Node, turn_manager: TurnManager) -> bool:
	if turn_manager == null or turn_manager.action_queue == null:
		return false
	if turn_manager.action_queue.is_busy():
		return false
	if not can_play(card, target):
		return false
	var action := CardAction.new(self, card, target)
	turn_manager.action_queue.queue_action(action)
	return true

func execute_card(card: CardData, target: Node) -> Dictionary:
	if not can_play(card, target):
		card_failed.emit(card, "invalid")
		return {"hit": false, "damage": 0, "reason": "invalid"}

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

	await _apply_runtime_effects(result, target_component)

	card_manager.start_cooldown(card)
	card_played.emit(card, target, result)
	if owner_actor and owner_actor.is_in_group("player") and card_manager:
		card_manager.set_active_index(-1)
	return result

func _apply_runtime_effects(result: Dictionary, target_component: CombatComponent) -> void:
	if target_component == null:
		return

	var target_actor := target_component.actor_owner
	for move_data in result.get("movement", []):
		if not (move_data is Dictionary):
			continue
		await _apply_movement_effect(move_data, target_actor)

	for status_data in result.get("statuses", []):
		if not (status_data is Dictionary):
			continue
		_apply_status_effect(status_data, target_component)

func _apply_movement_effect(move_data: Dictionary, target_actor: Node) -> void:
	if map_manager == null:
		return

	var receiver := owner_actor if str(move_data.get("target", "source")) == "source" else target_actor
	if receiver == null:
		return
	if not receiver.has_method("begin_step_move") or not receiver.has_method("wait_for_step"):
		return

	var move_cells: int = max(1, int(move_data.get("move_cells", 1)))
	var movement_mode: String = str(move_data.get("movement_mode", "dash"))
	var reference := target_actor if receiver == owner_actor else owner_actor
	var direction := _resolve_movement_direction(receiver, reference, movement_mode)
	if direction == Vector2i.ZERO:
		return

	for _i in range(move_cells):
		var from_cell : Vector2i = CardTargeting.get_actor_cell(receiver, map_manager)
		if from_cell == null:
			break

		var next_cell: Vector2i = from_cell + direction
		if not map_manager.is_walkable_cell_for_actor(next_cell, receiver):
			break

		receiver.begin_step_move(next_cell)
		await receiver.wait_for_step()
		map_manager.update_actor_cell(receiver, next_cell)

func _apply_status_effect(status_data: Dictionary, target_component: CombatComponent) -> void:
	var receiver_component: CombatComponent = combat_component if str(status_data.get("target", "target")) == "source" else target_component
	if receiver_component == null:
		return
	StatusRuntime.apply_status(receiver_component.actor_owner, receiver_component.stats, status_data)

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
