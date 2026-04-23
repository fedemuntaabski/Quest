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

# Execute player attack with a skill card
func player_attack(card: SkillCard) -> Dictionary:
	"""
	Execute player attack using the given skill card.
	Returns attack result dictionary.
	"""
	if current_state != State.PLAYER_COMBAT or not player or not current_enemy:
		push_error("TurnManager: Cannot execute attack outside PLAYER_COMBAT or without combatants")
		return {}
	
	# Calculate success using card and player stats
	var attack_result = card.calculate_success(player)
	
	# Apply damage to enemy
	var damage = attack_result.get("damage", 0)
	var old_hp = current_enemy.current_hp
	current_enemy.take_damage(damage)
	var new_hp = current_enemy.current_hp
	
	# Build detailed log entry
	var attack_log = {
		"attacker": player.character_name,
		"skill": card.card_name,
		"roll": attack_result.get("roll", 0),
		"modifier": attack_result.get("character_modifier", 0),
		"dice_bonus": attack_result.get("dice_bonus", 0),
		"total": attack_result.get("total", 0),
		"intensity": attack_result.get("intensity", 0),
		"damage": damage,
		"target_hp_before": old_hp,
		"target_hp_after": new_hp
	}
	combat_log.append(attack_log)
	
	# Print to console
	_print_attack_result(attack_log, card)
	
	# Check if enemy is defeated
	if not current_enemy.is_alive():
		_on_combat_victory()
	else:
		# Transition to enemy turn
		set_state(State.ENEMY_COMBAT)
		call_deferred("_execute_enemy_turn")
	
	attack_resolved.emit(attack_log)
	return attack_log

# Execute enemy AI attack (placeholder)
func _execute_enemy_turn() -> void:
	"""Enemy turn logic (currently just a random attack)"""
	if not current_state == State.ENEMY_COMBAT or not player or not current_enemy:
		return
	
	await get_tree().create_timer(1.0).timeout  # Delay for drama
	
	print("\n--- ENEMY TURN ---")
	
	# Simple enemy attack: random 1d6 damage
	var enemy_damage = randi_range(1, 6)
	var old_hp = player.current_hp
	player.take_damage(enemy_damage)
	var new_hp = player.current_hp
	
	print("%s attacks for %d damage! (Player: %d → %d HP)" % [current_enemy.character_name, enemy_damage, old_hp, new_hp])
	
	# Check if player is defeated
	if not player.is_alive():
		_on_combat_defeat()
	else:
		# Back to player turn
		set_state(State.PLAYER_COMBAT)
		print("\n--- PLAYER TURN ---")

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
	current_state = State.EXPLORATION
	player = null
	current_enemy = null
	player_skills = []
	combat_log = []
	print("TurnManager: Exiting combat - returning to exploration")
	set_state(State.EXPLORATION)

# Print formatted attack result
func _print_attack_result(attack_log: Dictionary, card: SkillCard) -> void:
	var intensity_text = ["MISS", "HIT", "CRIT"][attack_log.get("intensity", 0)]
	var stat_name = GameManager.get_stat(attack_log.get("stat_type", ""))
	
	print("\n[ATTACK] %s uses '%s' (%s)" % [attack_log.get("attacker"), card.card_name, stat_name])
	print("  Dice Roll:        %d" % attack_log.get("roll"))
	print("  Stat Modifier:    +%d" % attack_log.get("modifier"))
	print("  Dice Bonus:       +%d" % attack_log.get("dice_bonus"))
	print("  Total:            %d" % attack_log.get("total"))
	print("  Result:           %s" % intensity_text)
	print("  Damage Dealt:     %d" % attack_log.get("damage"))
	print("  Enemy HP:         %d → %d" % [attack_log.get("target_hp_before"), attack_log.get("target_hp_after")])

# Get current combat state name
func get_state_name() -> String:
	return State.keys()[current_state]

# Debug: Print combat log
func debug_print_combat_log() -> void:
	print("\n=== COMBAT LOG ===")
	for i in range(combat_log.size()):
		var entry = combat_log[i]
		print("[%d] %s: %s (Total: %d, Damage: %d)" % [i, entry.get("attacker"), entry.get("skill"), entry.get("total"), entry.get("damage")])
	print("==================\n")
