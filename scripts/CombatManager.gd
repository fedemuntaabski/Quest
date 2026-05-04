extends Node
class_name CombatManager

signal turn_started(entity)
signal turn_finished(entity)


@onready var player_controller: PlayerActionController



var player: CharacterBody2D
var enemies: Array = []
var map_manager: MapManager

var current_turn_index: int = 0
var turn_order: Array = []

var in_combat: bool = false

func start_combat(p_player: CharacterBody2D, p_enemies: Array, p_map_manager: MapManager):
	player = p_player
	enemies = p_enemies
	map_manager = p_map_manager
	player_controller.setup(player, map_manager)

	in_combat = true
	_build_turn_order()
	current_turn_index = 0
	_start_turn()

func _build_turn_order():
	turn_order = []
	turn_order.append(player)
	for e in enemies:
		if is_instance_valid(e):
			turn_order.append(e)

func _start_turn():
	if not in_combat:
		return

	if current_turn_index >= turn_order.size():
		current_turn_index = 0

	var entity = turn_order[current_turn_index]

	if entity == null or not is_instance_valid(entity):
		_next_turn()
		return

	turn_started.emit(entity)

	if entity == player:
		_handle_player_turn()
	else:
		_handle_enemy_turn(entity)

func _handle_enemy_turn(enemy: Enemy):
	var intent = EnemyAI.get_action(enemy, player, map_manager)

	_execute_intent(enemy, intent)

	_finish_turn(enemy)

func _handle_player_turn():
	var intent = player_controller.get_action()

	_execute_intent(player, intent)

	_finish_turn(player)

func _execute_intent(actor, intent: Dictionary):
	match intent.get("type"):

		"move":
			_execute_move(actor, intent)

		"attack":
			_execute_attack(actor, intent)

		_:
			pass

func _execute_move(actor, intent):
	if actor == null:
		return

	if intent.has("move"):
		actor.global_position += map_manager.grid_to_world_offset(intent["move"])

func _execute_attack(actor, intent):
	var target = _find_target(actor, intent)

	if target == null:
		return

	var result = CombatRules.resolve_action(
		intent,
		actor.stats,
		target.stats
	)

	target.apply_damage(result["damage"])

func _find_target(actor, intent):
	if actor == player:
		return enemies[0] if enemies.size() > 0 else null

	return player

func _finish_turn(entity):
	turn_finished.emit(entity)
	_next_turn()

func _next_turn():
	current_turn_index += 1
	_start_turn()

func remove_dead():
	enemies = enemies.filter(func(e):
		return is_instance_valid(e) and e.stats.current_hp > 0
	)
