extends Node
class_name CombatComponent

const CombatResolverScript = preload("res://scripts/CombatResolver.gd")

@export var attack_range: int = 1
@export var attack_stat: String = "strength"
@export var base_damage: int = 0

var actor_owner: Node = null
var stats: CharacterStats = null
var map_manager: MapManager = null
var occupancy: OccupancyManager = null

func setup(p_owner: Node, p_stats: CharacterStats, p_map_manager: MapManager) -> void:
	actor_owner = p_owner
	stats = p_stats
	map_manager = p_map_manager
	occupancy = map_manager.occupancy_manager if map_manager else null

func can_attack(target: Node) -> bool:
	var target_component := _resolve_target_component(target)
	if target_component == null:
		return false

	if stats == null or target_component.stats == null:
		return false

	if not stats.is_alive() or not target_component.stats.is_alive():
		return false

	return _is_in_range(target_component)

func attack(target: Node) -> Dictionary:
	var target_component := _resolve_target_component(target)
	if target_component == null:
		return {"hit": false, "crit": false, "damage": 0, "reason": "no_target"}

	if not can_attack(target_component):
		return {"hit": false, "crit": false, "damage": 0, "reason": "out_of_range"}

	var result := CombatResolverScript.resolve_attack(stats, target_component.stats, attack_stat, base_damage)
	if result.get("hit", false):
		target_component.receive_damage(result.get("damage", 0))

	return result

func receive_damage(amount: int) -> void:
	if stats == null:
		return

	stats.take_damage(amount)

func _is_in_range(target_component: CombatComponent) -> bool:
	var my_cell: Variant = _get_actor_cell(actor_owner)
	var target_cell: Variant = _get_actor_cell(target_component.actor_owner)
	if my_cell == null or target_cell == null:
		return false

	var dx := absi(my_cell.x - target_cell.x)
	var dy := absi(my_cell.y - target_cell.y)
	return (dx + dy) <= attack_range

func _get_actor_cell(actor: Node) -> Variant:
	if actor == null:
		return null

	if occupancy:
		var cell: Variant = occupancy.get_actor_cell(actor)
		if cell != null:
			return cell

	if actor.has_method("sync_to_grid") and actor.get("grid_pos") is Vector2i:
		return actor.get("grid_pos")

	if map_manager:
		return map_manager.world_to_grid_coords(actor.global_position)

	return null

func _resolve_target_component(target: Node) -> CombatComponent:
	if target == null:
		return null

	if target is CombatComponent:
		return target

	return target.get_node_or_null("CombatComponent") as CombatComponent
