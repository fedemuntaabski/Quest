extends Node
class_name GameStateManager

## GameStateManager: global gameplay state machine and gate keeper.
## Responsibilities:
## - Represent high-level modes (ACTIVE, PAUSED, DEAD, VICTORY, REWARD).
## - Provide `can_process_*` helpers used throughout to pause game logic.
## - Emit state transition signals so UI and orchestration (Main2d, TurnManager)
##   can react without tight coupling.

enum State {
	ACTIVE,
	PAUSED,
	DEAD,
	VICTORY,
	REWARD
}

signal state_changed(new_state: State, old_state: State)
signal pause_requested
signal resume_requested
signal death_entered
signal victory_entered
signal reward_entered(cards: Array)
signal reward_exited(card_selected: CardData)

var current_state: State = State.ACTIVE
var _previous_state: State = State.ACTIVE
var _state_stack: Array[State] = []

func _ready() -> void:
	add_to_group("game_state_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_state_stack = [current_state]

func get_state() -> State:
	return current_state

func is_active() -> bool:
	return current_state == State.ACTIVE

func is_paused() -> bool:
	return current_state == State.PAUSED

func is_dead() -> bool:
	return current_state == State.DEAD

func is_reward() -> bool:
	return current_state == State.REWARD

func can_process_input() -> bool:
	return current_state == State.ACTIVE

func can_update_overlays() -> bool:
	return current_state == State.ACTIVE

func can_process_turns() -> bool:
	return current_state == State.ACTIVE

func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	_state_stack.clear()
	_state_stack.append(new_state)
	_apply_state_change(new_state, current_state)

func push_state(new_state: State) -> void:
	if current_state == new_state:
		return
	_state_stack.append(new_state)
	_apply_state_change(new_state, current_state)

func pop_state(expected_state: int = -1) -> void:
	if _state_stack.size() <= 1:
		return
	if expected_state != -1 and current_state != expected_state:
		Logger.error(Logger.Category.STATE, "Expected state %s but current is %s" % [State.keys()[expected_state], State.keys()[current_state]])
		return
	var old_state := current_state
	_state_stack.pop_back()
	var next_state: State = _state_stack[_state_stack.size() - 1]
	_apply_state_change(next_state, old_state)

func request_pause() -> void:
	if current_state == State.ACTIVE:
		push_state(State.PAUSED)
		pause_requested.emit()

func request_resume() -> void:
	if current_state == State.PAUSED:
		pop_state(State.PAUSED)
		resume_requested.emit()

func request_death() -> void:
	if current_state != State.DEAD:
		_state_stack.clear()
		_state_stack.append(State.DEAD)
		_apply_state_change(State.DEAD, current_state)
		death_entered.emit()

func request_victory() -> void:
	# Push a victory state if currently active
	if current_state == State.ACTIVE:
		push_state(State.VICTORY)
		victory_entered.emit()

func request_reward(card_options: Array) -> void:
	if current_state == State.ACTIVE:
		push_state(State.REWARD)
		reward_entered.emit(card_options)

func close_reward(selected_card: CardData) -> void:
	Logger.debug(Logger.Category.STATE, "close_reward() called, current_state=%s" % State.keys()[current_state])
	if current_state == State.REWARD:
		Logger.debug(Logger.Category.STATE, "Popping REWARD state...")
		pop_state(State.REWARD)
		Logger.info(Logger.Category.STATE, "New state after pop: %s" % State.keys()[current_state])
		reward_exited.emit(selected_card)
	else:
		Logger.warn(Logger.Category.STATE, "close_reward() called but current_state is %s, not REWARD!" % State.keys()[current_state])

func toggle_pause() -> void:
	if current_state == State.ACTIVE:
		request_pause()
	elif current_state == State.PAUSED:
		request_resume()

func return_to_previous_state() -> void:
	pop_state()

func _apply_state_change(new_state: State, old_state: State) -> void:
	_previous_state = old_state
	current_state = new_state
	_handle_state_change(current_state, _previous_state)
	state_changed.emit(current_state, _previous_state)

func _handle_state_change(new_state: State, _old_state: State) -> void:
	Logger.info(Logger.Category.STATE, "State transition: %s -> %s" % [State.keys()[_old_state], State.keys()[new_state]])
	match new_state:
		State.ACTIVE:
			get_tree().paused = false
		State.PAUSED, State.DEAD, State.VICTORY, State.REWARD:
			get_tree().paused = true
