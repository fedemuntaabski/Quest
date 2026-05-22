extends Node
class_name PotionController

var potion_button: Button = null
var potion_count_label: Label = null
var potion_icon: Control = null
var _potion_used: bool = false
var _game_state_manager: GameStateManager = null
var _bound_stats: CharacterStats = null

const POTION_HEAL_RATIO: float = 0.5

func setup(button: Button, count_label: Label, icon: Control) -> void:
	potion_button = button
	potion_count_label = count_label
	potion_icon = icon
	if potion_button and not potion_button.pressed.is_connected(_on_potion_pressed):
		potion_button.pressed.connect(_on_potion_pressed)
	_bind_game_state()
	refresh()

func bind_stats(stats: CharacterStats) -> void:
	_bound_stats = stats
	refresh()

func _bind_game_state() -> void:
	_game_state_manager = get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if _game_state_manager and not _game_state_manager.state_changed.is_connected(_on_game_state_changed):
		_game_state_manager.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(_new_state: GameStateManager.State, _old_state: GameStateManager.State) -> void:
	refresh()

func _on_potion_pressed() -> void:
	if _potion_used:
		return
	if not _can_use_potion_now():
		return
	if _bound_stats == null:
		var ps = get_node_or_null("/root/PlayerStats")
		if ps == null or ps.stats == null:
			return
		_bound_stats = ps.stats
	if _bound_stats == null:
		return
	var stats: CharacterStats = _bound_stats
	var heal_amount: int = int(ceil(float(stats.max_hp) * POTION_HEAL_RATIO))
	if heal_amount <= 0:
		return
	stats.heal(heal_amount)
	_potion_used = true
	refresh()

func _can_use_potion_now() -> bool:
	if _potion_used:
		return false
	if _game_state_manager and not _game_state_manager.is_active():
		return false
	if _bound_stats == null:
		var ps = get_node_or_null("/root/PlayerStats")
		if ps == null or ps.stats == null:
			return false
		_bound_stats = ps.stats
	if _bound_stats == null:
		return false
	var stats: CharacterStats = _bound_stats
	return stats.current_hp < stats.max_hp

func refresh() -> void:
	if potion_button:
		potion_button.disabled = not _can_use_potion_now()
		potion_button.text = "Usar" if not _potion_used else "Usada"
	if potion_count_label:
		potion_count_label.text = "x0" if _potion_used else "x1"
	if potion_icon:
		potion_icon.modulate = Color(1, 1, 1, 1) if not _potion_used else Color(0.5, 0.5, 0.5, 0.8)
