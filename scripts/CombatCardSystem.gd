extends Node
class_name CombatCardSystem

signal card_played(card: CardData, target: Node, result: Dictionary)
signal card_failed(card: CardData, reason: String)

const CardTargeting = preload("res://scripts/CardTargeting.gd")
const CardResolver = preload("res://scripts/CardResolver.gd")
const CardAction = preload("res://scripts/CardAction.gd")

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

	card_manager.start_cooldown(card)
	card_played.emit(card, target, result)
	if owner_actor and owner_actor.is_in_group("player") and card_manager:
		card_manager.set_active_index(-1)
	return result

func _resolve_target_component(target: Node) -> CombatComponent:
	if target == null:
		return null
	if target is CombatComponent:
		return target
	if target.has_method("get_combat_component"):
		return target.get_combat_component() as CombatComponent
	return target.get_node_or_null("CombatComponent") as CombatComponent
