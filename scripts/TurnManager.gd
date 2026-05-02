extends Node

# ─────────────────────────────────────────────
# STATES
# ─────────────────────────────────────────────
enum State {
	EXPLORATION,
	PLAYER_TURN,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
signal state_changed(new_state: State)
signal combat_started(player: CharacterStats, enemy: CharacterStats)
signal combat_ended(victor: String)
signal attack_resolved(result: Dictionary)

# ─────────────────────────────────────────────
# STATE TRACKING
# ─────────────────────────────────────────────
var current_state: State = State.EXPLORATION
var player: CharacterStats
var current_enemy: CharacterStats
var player_skills: Array = []
var map_manager: MapManager
var combat_log: Array = []

# ─────────────────────────────────────────────
func _ready() -> void:
	print("TurnManager initialized - Turn system active")

# ─────────────────────────────────────────────
# STATE CONTROL
# ─────────────────────────────────────────────
func set_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	print("TurnManager: State changed to %s" % State.keys()[new_state])
	state_changed.emit(new_state)

func start_game() -> void:
	set_state(State.PLAYER_TURN)

# ─────────────────────────────────────────────
# GRID TURN FLOW (ToME STYLE)
# ─────────────────────────────────────────────
func request_player_move(dir: Vector2i) -> void:
	if current_state != State.PLAYER_TURN:
		return

	if player == null or map_manager == null:
		return

	var next: Vector2i = player.grid_pos + dir

	# ❌ pared
	if not map_manager.is_walkable_cell(next):
		return

	# 🔥 BUMP COMBAT CHECK
	var enemy = map_manager.get_enemy_at_cell(next)

	if enemy != null:
		# atacar en vez de moverse
		_handle_bump_attack(enemy)
		end_player_turn()
		return

	# ✔ movimiento normal
	player.try_move(dir)
	end_player_turn()

func _handle_bump_attack(enemy: Node) -> void:
	if enemy == null or player == null:
		return

	print("BUMP ATTACK on %s" % enemy.name)

	if enemy.has_method("receive_hit"):
		var damage = 3 # o tu sistema de stats
		enemy.receive_hit(damage)

func end_player_turn() -> void:
	set_state(State.ENEMY_TURN)
	call_deferred("_execute_enemy_turn")

func _on_enemy_turn_finished() -> void:
	set_state(State.PLAYER_TURN)

# ─────────────────────────────────────────────
# DAMAGE SYSTEM
# ─────────────────────────────────────────────
func _apply_damage(target: CharacterStats, amount: int) -> void:
	if target:
		target.take_damage(amount)

# ─────────────────────────────────────────────
# PLAYER ATTACK (UNCHANGED CORE LOGIC)
# ─────────────────────────────────────────────
func player_attack(card: SkillCard) -> Dictionary:
	if not player or not current_enemy:
		return {}

	var result = CombatRules.resolve_player_attack(card, player, current_enemy)

	_apply_damage(current_enemy, result["damage"])
	result["target_hp_after"] = current_enemy.current_hp

	combat_log.append(result)
	attack_resolved.emit(result)

	if not current_enemy.is_alive():
		_on_victory()
	else:
		end_player_turn()

	return result

# ─────────────────────────────────────────────
# ENEMY TURN
# ─────────────────────────────────────────────
func _execute_enemy_turn() -> void:
	if not player or not current_enemy:
		return

	await get_tree().create_timer(1.0).timeout

	print("\n--- ENEMY TURN ---")

	var action = EnemyAI.get_action(current_enemy, player, map_manager)

	_apply_damage(player, action["damage"])

	print("%s attacks for %d damage!" % [
		current_enemy.character_name,
		action["damage"]
	])

	if not player.is_alive():
		_on_defeat()
		return

	_on_enemy_turn_finished()

# ─────────────────────────────────────────────
# VICTORY / DEFEAT
# ─────────────────────────────────────────────
func _on_victory() -> void:
	set_state(State.VICTORY)

	print("\n*** VICTORY ***")
	print("%s has defeated %s!" % [
		player.character_name,
		current_enemy.character_name
	])

	combat_ended.emit("player")

func _on_defeat() -> void:
	set_state(State.DEFEAT)

	print("\n*** DEFEAT ***")
	print("%s has been defeated by %s!" % [
		player.character_name,
		current_enemy.character_name
	])

	combat_ended.emit("enemy")

# ─────────────────────────────────────────────
# RESET / EXIT
# ─────────────────────────────────────────────
func exit_combat() -> void:
	player = null
	current_enemy = null
	player_skills.clear()
	combat_log.clear()

	print("TurnManager: Returning to exploration")
	set_state(State.EXPLORATION)

# ─────────────────────────────────────────────
# DEBUG
# ─────────────────────────────────────────────
func get_state_name() -> String:
	return State.keys()[current_state]

func debug_print_combat_log() -> void:
	print("\n=== COMBAT LOG ===")

	for i in range(combat_log.size()):
		var entry = combat_log[i]
		print("[%d] %s: %s (Total: %d, Damage: %d)" % [
			i,
			entry.get("attacker", "unknown"),
			entry.get("skill", "enemy_attack"),
			entry.get("total", 0),
			entry.get("damage", 0)
		])

	print("==================\n")
