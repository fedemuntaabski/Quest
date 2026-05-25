extends Node
class_name CombatComponent

const CombatResolverScript = preload("res://scripts/core/combat/CombatResolver.gd")

# CombatComponent: per-actor combat API owned by an actor node.
# Responsibilities:
# - Hold references to owner actor, stats and map manager.
# - Provide high-level attack/receive_damage methods that delegate
#   math to CombatResolver and validation to CombatValidation.
# Runtime ownership: typically created/attached by movement or enemy/player
# setup code and lives under the actor node.

@export var attack_range: int = 1
@export var attack_stat: String = "strength"
@export var base_damage: int = 0
@export_range(0.0, 1.0, 0.01) var forced_miss_chance: float = 0.0

var actor_owner: Node = null
var stats: CharacterStats = null
var map_manager: MapManager = null

func setup(p_owner: Node, p_stats: CharacterStats, p_map_manager: MapManager) -> void:
	# Called during actor initialization to bind runtime owners and
	# infer missing `Stats` nodes when necessary.
	actor_owner = p_owner
	map_manager = p_map_manager

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
	return bool(CombatValidation.validate_target(self, target, map_manager, attack_range, true).get("valid", false))

func attack(target: Node) -> Dictionary:
	# Perform validation, resolve target, run resolve_attack and apply
	# damage via `receive_damage`. HUD update occurs for player-owned actors.
	var validation := CombatValidation.validate_target(self, target, map_manager, attack_range, true)
	if not bool(validation.get("valid", false)):
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": validation.get("reason", "invalid")
		}

	var target_component := validation.get("target_component") as CombatComponent
	if target_component == null:
		return {
			"hit": false,
			"crit": false,
			"damage": 0,
			"reason": "no_target"
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
			hud.show_combat_result(result)

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
