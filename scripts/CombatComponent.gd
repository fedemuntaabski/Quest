extends Node
class_name CombatComponent

const CombatResolverScript = preload("res://scripts/CombatResolver.gd")

@export var attack_range: int = 1
@export var attack_stat: String = "strength"
@export var base_damage: int = 0
@export_range(0.0, 1.0, 0.01) var forced_miss_chance: float = 0.0

var actor_owner: Node = null
var stats: CharacterStats = null
var map_manager: MapManager = null
var occupancy: OccupancyManager = null

func setup(p_owner: Node, p_stats: CharacterStats, p_map_manager: MapManager) -> void:
	actor_owner = p_owner
	map_manager = p_map_manager
	occupancy = map_manager.occupancy_manager if map_manager else null

	if p_stats == null and actor_owner:
		p_stats = actor_owner.get_node_or_null("Stats") as CharacterStats

	if p_stats == null:
		push_warning("CombatComponent.setup(): stats is null, creating fallback CharacterStats")
		p_stats = CharacterStats.new()
		p_stats.name = "Stats"
		if actor_owner:
			actor_owner.add_child(p_stats)

	stats = p_stats

func can_attack(target: Node) -> bool:
	var target_component := _resolve_target_component(target)

	if target_component == null:
		return false

	if stats == null or target_component.stats == null:
		return false

	if not stats.is_alive() or not target_component.stats.is_alive():
		return false

	if actor_owner and actor_owner.has_method("sync_to_grid"):
		actor_owner.sync_to_grid()
	if target_component.actor_owner and target_component.actor_owner.has_method("sync_to_grid"):
		target_component.actor_owner.sync_to_grid()
	if map_manager and not map_manager.can_actors_engage(actor_owner, target_component.actor_owner):
		return false

	return _is_in_range(target_component)

func attack(target: Node) -> Dictionary:
	var target_component := _resolve_target_component(target)

	if target_component == null:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "no_target"
		}

	if not can_attack(target):
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "out_of_range"
		}

	if forced_miss_chance > 0.0 and randf() < forced_miss_chance:
		var forced_miss_result := {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "forced_miss"
		}
		var forced_target_actor := target_component.actor_owner
		if forced_target_actor and forced_target_actor.has_method("show_miss"):
			forced_target_actor.show_miss()
		return forced_miss_result

	var result := CombatResolverScript.resolve_attack(
		stats,
		target_component.stats,
		attack_stat,
		base_damage
	)
	if actor_owner and actor_owner.is_in_group("player"):
		var hud := get_tree().get_first_node_in_group("hud") as HUDController
		if hud:
			hud.set_roll_label_from_result(result)

	if result.get("hit", false):
		target_component.receive_damage(
			result.get("damage", 0),
			result.get("crit", false)
		)
	else:
		var target_actor := target_component.actor_owner
		if target_actor and target_actor.has_method("show_miss"):
			target_actor.show_miss()

	return result

func receive_damage(amount: int, crit: bool = false) -> void:
	if stats == null:
		return

	print("[Combat] Damage applied: ", amount, " Crit: ", crit)
	stats.take_damage(amount)
	if actor_owner and actor_owner.has_method("show_damage"):
		actor_owner.show_damage(amount, crit)

func _is_in_range(target_component: CombatComponent) -> bool:
	var my_cell: Variant = _get_actor_cell(actor_owner)
	var target_cell: Variant = _get_actor_cell(target_component.actor_owner)

	if my_cell == null or target_cell == null:
		return false

	var dx := absi(my_cell.x - target_cell.x)
	var dy := absi(my_cell.y - target_cell.y)
	var chebyshev: int = max(dx, dy)

	var result: bool = chebyshev <= attack_range

	return result

func _get_actor_cell(actor: Node) -> Variant:
	if actor == null:
		return null

	if actor.get("grid_pos") != null:
		return actor.get("grid_pos")

	if occupancy:
		var cell: Variant = occupancy.get_actor_cell(actor)
		if cell != null:
			return cell

	if map_manager:
		return map_manager.world_to_grid_coords(actor.global_position)

	return null

func _resolve_target_component(target: Node) -> CombatComponent:
	if target == null:
		return null

	if target == self:
		return self

	if target is CombatComponent:
		return target

	if target.has_method("get_combat_component"):
		return target.get_combat_component() as CombatComponent

	return target.get_node_or_null("CombatComponent") as CombatComponent
