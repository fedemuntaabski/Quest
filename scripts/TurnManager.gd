extends Node

# Combat states
enum State {EXPLORATION, PLAYER_COMBAT, ENEMY_COMBAT, VICTORY, DEFEAT}

# Signals
signal state_changed(new_state: State)
signal combat_started(player: CharacterStats, enemy: CharacterStats)
signal combat_ended(victor: String)
signal attack_resolved(result: Dictionary)

# State tracking
var current_state: State = State.EXPLORATION
var player: CharacterStats
var current_enemy: CharacterStats
var player_skills: Array = []  # Equipped SkillCard objects

# Combat history for console logging
var combat_log: Array = []

func _ready():
	print("TurnManager initialized - Combat state machine active")

# Switch to a new state
func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	var state_name = State.keys()[new_state]
	print("TurnManager: State changed to %s" % state_name)
	state_changed.emit(new_state)

# Initialize combat with enemy
func initiate_combat(enemy_stats: CharacterStats, player_stats: CharacterStats, equipped_cards: Array = []) -> void:
	"""
	Start combat encounter.
	equipped_cards should be an array of SkillCard objects or dictionaries
	"""
	player = player_stats
	current_enemy = enemy_stats
	player_skills = equipped_cards
	
	set_state(State.PLAYER_COMBAT)
	
	print("\n=== COMBAT INITIATED ===")
	print("Player: %s (HP: %d/%d)" % [player.character_name, player.current_hp, player.max_hp])
	print("Enemy: %s (HP: %d/%d)" % [current_enemy.character_name, current_enemy.current_hp, current_enemy.max_hp])
	print("========================\n")
	
	combat_started.emit(player, current_enemy)

func _apply_damage(target: CharacterStats, amount: int) -> void:
	target.take_damage(amount)
	
# Execute player attack with a skill card
func player_attack(card: SkillCard) -> Dictionary:
	if current_state != State.PLAYER_COMBAT or not player or not current_enemy:
		push_error("TurnManager: Cannot execute attack outside PLAYER_COMBAT or without combatants")
		return {}

	var result = CombatRules.resolve_player_attack(card, player, current_enemy)

	_apply_damage(current_enemy, result["damage"])
	result["target_hp_after"] = current_enemy.current_hp

	combat_log.append(result)

	attack_resolved.emit(result)

	if not current_enemy.is_alive():
		_on_combat_victory()
	else:
		set_state(State.ENEMY_COMBAT)
		call_deferred("_execute_enemy_turn")

	return result

# Execute enemy AI attack (placeholder)
func _execute_enemy_turn() -> void:
	if current_state != State.ENEMY_COMBAT or not player or not current_enemy:
		return

	await get_tree().create_timer(1.0).timeout

	print("\n--- ENEMY TURN ---")

	var action = EnemyAI.get_action(current_enemy, player)

	_apply_damage(player, action["damage"])

	print("%s attacks for %d damage!" % [
		current_enemy.character_name,
		action["damage"]
	])

# Victory condition
func _on_combat_victory() -> void:
	set_state(State.VICTORY)
	print("\n*** VICTORY ***")
	print("%s has defeated %s!" % [player.character_name, current_enemy.character_name])
	combat_ended.emit("player")

# Defeat condition
func _on_combat_defeat() -> void:
	set_state(State.DEFEAT)
	print("\n*** DEFEAT ***")
	print("%s has been defeated by %s!" % [player.character_name, current_enemy.character_name])
	combat_ended.emit("enemy")

# Exit combat and return to exploration
func exit_combat() -> void:
	"""End combat and return to exploration"""
	player = null
	current_enemy = null
	player_skills = []
	combat_log = []
	print("TurnManager: Exiting combat - returning to exploration")
	set_state(State.EXPLORATION)


# Get current combat state name
func get_state_name() -> String:
	return State.keys()[current_state]

# Debug: Print combat log
func debug_print_combat_log() -> void:
	print("\n=== COMBAT LOG ===")
	for i in range(combat_log.size()):
		var entry = combat_log[i]
		print("[%d] %s: %s (Total: %d, Damage: %d)" % [i, entry.get("attacker"), entry.get("skill", "enemy_attack"), entry.get("total"), entry.get("damage")])
	print("==================\n")
