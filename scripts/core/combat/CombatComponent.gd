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
const ATTACK_STAT := "dexterity"
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
			"reason": "forced_miss",
			"gold": 0,
			"gold_earned": 0
		}
		var forced_target_actor := target_component.actor_owner
		if forced_target_actor and forced_target_actor.has_method("show_miss"):
			forced_target_actor.show_miss()
		return forced_miss_result

	var result := CombatResolverScript.resolve_attack(
		stats,
		target_component.stats,
		"dexterity",
		base_damage,
		1.0,
		target_component.actor_owner
	)

	# 🌟 MODIFICACIÓN: Calculamos y añadimos el oro antes de enviar el resultado al HUD
	if result.get("hit", false):
		var target_actor := target_component.actor_owner
		var damage_applied := int(result.get("damage", 0))
		
		# Verificamos si este golpe vacía la vida del enemigo (letal)
		var is_fatal := (target_component.stats.current_hp - damage_applied) <= 0
		
		if is_fatal and target_actor and target_actor.has_method("get_reward_gold"):
			var reward := int(target_actor.get_reward_gold())
			result["gold"] = reward
			result["gold_earned"] = reward
		else:
			result["gold"] = 0
			result["gold_earned"] = 0

		# Aplicamos el daño real en las estadísticas del objetivo
		target_component.receive_damage(
			damage_applied,
			result.get("crit", false)
		)
	else:
		var target_actor := target_component.actor_owner
		if target_actor and target_actor.has_method("show_miss"):
			target_actor.show_miss()
		result["gold"] = 0
		result["gold_earned"] = 0

	# 🌟 MODIFICACIÓN: El HUD se actualiza al final de la lógica para capturar el oro cargado
	if actor_owner and actor_owner.is_in_group("player"):
		var hud := get_tree().get_first_node_in_group("hud") as HUDController
		if hud:
			hud.show_combat_result(result)

	return result

func receive_damage(amount: int, crit: bool = false) -> void:
	if stats == null:
		return

	QuestLogger.debug(QuestLogger.Category.COMBAT, "Damage applied: %d Crit: %s" % [amount, str(crit)])
	stats.take_damage(amount)
	if actor_owner and actor_owner.has_method("show_damage"):
		actor_owner.show_damage(amount, crit)
