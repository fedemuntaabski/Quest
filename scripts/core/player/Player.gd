extends Node2D
class_name Player

## Player: minimal test-scene actor. Owns a CharacterStats component and
## participates in TurnManager's turn loop. No movement/combat logic yet.

@onready var stats: CharacterStats = $Stats

var turn_manager: TurnManager

func _ready() -> void:
	add_to_group("player")
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.register(stats)

func begin_turn(tm: TurnManager) -> void:
	turn_manager = tm

func process_turn_end() -> void:
	if stats:
		stats.reset_runtime_modifiers()

func can_accept_input() -> bool:
	return stats != null and stats.has_ap()
