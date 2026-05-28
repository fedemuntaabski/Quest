extends RefCounted
class_name PlayerMovementTurnBridge

# Coordinates the turn-facing parts of player movement so PlayerMovement can stay
# focused on grid state, interpolation, and step completion.

const PRELOAD_MOVE_ACTION = preload("res://scripts/core/actions/MoveAction.gd")
const PRELOAD_WAIT_ACTION = preload("res://scripts/core/actions/WaitAction.gd")

var player: PlayerMovement = null
var map_manager: MapManager = null

# Setup
func setup(p_player: PlayerMovement, p_map_manager: MapManager) -> void:
	player = p_player
	map_manager = p_map_manager

# Public turn-facing API
func on_game_state_changed(new_state: GameStateManager.State, _old_state: GameStateManager.State) -> void:
	if new_state != GameStateManager.State.ACTIVE and player:
		player.cancel_movement()

func can_accept_input() -> bool:
	if player == null:
		return false

	var gsm := player.get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if gsm and not gsm.is_active():
		return false
	if not player.is_turn_active():
		return false
	if player.turn_manager and player.turn_manager.action_queue and player.turn_manager.action_queue.is_busy():
		return false
	return true

func request_move(dir: Vector2i) -> bool:
	if not can_accept_input():
		return false
	if player.is_moving_step:
		return false
	if map_manager == null:
		return false

	var next := player.grid_pos + dir
	if not map_manager.is_walkable_cell_for_actor(next, player):
		if OS.is_debug_build() and map_manager.core:
			var state := map_manager.core.describe_cell_state_for_actor(next, player)
			print("PlayerMovementTurnBridge: move rejected next=%s reason=%s nav_walkable=%s blocked=%s allowed=%s room_id=%d active_room=%d room_locked=%s" % [
				str(state.get("cell", next)),
				String(state.get("reason", "unknown")),
				str(state.get("nav_walkable", false)),
				str(state.get("blocked", false)),
				str(state.get("allowed_for_actor", false)),
				int(state.get("room_id", -1)),
				int(state.get("active_room", -1)),
				str(state.get("room_locked", false))
			])
		return false
	if player.turn_manager == null or player.turn_manager.action_queue == null:
		return false

	var snapshot: Dictionary = {}
	if map_manager.occupancy_manager:
		snapshot["occ_version"] = map_manager.occupancy_manager.get_version()
	snapshot["owner_cell"] = player.grid_pos
	snapshot["target_cell"] = next
	var action: BaseAction = PRELOAD_MOVE_ACTION.new(player, map_manager, next, false, snapshot)
	player.turn_manager.action_queue.queue_action(action)
	return true

func begin_turn(tm: TurnManager) -> void:
	if player == null:
		return

	player.turn_manager = tm
	player.sync_to_grid()

	if player.stats and player.stats.is_alive():
		var status_component := player.get_node_or_null("StatusComponent") as StatusComponent
		if status_component != null:
			var status_result := status_component.process_turn_start(player, player.stats)
			if status_result.get("can_act", true) != true:
				if player.turn_manager and player.turn_manager.action_queue:
					player.turn_manager.action_queue.queue_action(PRELOAD_WAIT_ACTION.new(player, null))
				return

	if player.action_controller and player.action_controller.has_method("on_player_turn_started"):
		player.action_controller.on_player_turn_started()
