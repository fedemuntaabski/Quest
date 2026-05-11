extends Node
class_name GameStateManager

enum State {
	ACTIVE,
	PAUSED,
	DEAD,
	REWARD
}

signal state_changed(new_state: State, old_state: State)
signal pause_requested
signal resume_requested
signal death_entered
signal reward_entered(cards: Array)
signal reward_exited(card_selected: CardData)

var current_state: State = State.ACTIVE
var _previous_state: State = State.ACTIVE

func _ready() -> void:
	add_to_group("game_state_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	return current_state == State.ACTIVE or current_state == State.REWARD

func can_update_overlays() -> bool:
	return current_state == State.ACTIVE or current_state == State.REWARD

func can_process_turns() -> bool:
	return current_state == State.ACTIVE or current_state == State.REWARD

func set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	_previous_state = current_state
	current_state = new_state
	
	_handle_state_change(current_state, _previous_state)
	state_changed.emit(current_state, _previous_state)

func request_pause() -> void:
	if current_state == State.ACTIVE:
		set_state(State.PAUSED)
		pause_requested.emit()

func request_resume() -> void:
	if current_state == State.PAUSED:
		set_state(State.ACTIVE)
		resume_requested.emit()

func request_death() -> void:
	if current_state != State.DEAD:
		_previous_state = current_state
		set_state(State.DEAD)
		death_entered.emit()

func request_reward(card_options: Array) -> void:
	if current_state == State.ACTIVE:
		_previous_state = current_state
		set_state(State.REWARD)
		reward_entered.emit(card_options)

func close_reward(selected_card: CardData) -> void:
	if current_state == State.REWARD:
		set_state(State.ACTIVE)
		reward_exited.emit(selected_card)

func toggle_pause() -> void:
	if current_state == State.ACTIVE:
		request_pause()
	elif current_state == State.PAUSED:
		request_resume()

func return_to_previous_state() -> void:
	set_state(_previous_state)

func _handle_state_change(new_state: State, _old_state: State) -> void:
	match new_state:
		State.ACTIVE:
			get_tree().paused = false
		State.PAUSED:
			get_tree().paused = true
		State.DEAD:
			get_tree().paused = true
		State.REWARD:
			get_tree().paused = false
