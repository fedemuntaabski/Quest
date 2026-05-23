extends Node
class_name PotionController

var potion_button: Button = null
var potion_count_label: Label = null
var potion_icon: Control = null
var _game_state_manager: GameStateManager = null
var _bound_stats: CharacterStats = null

func setup(button: Button, count_label: Label, icon: Control) -> void:
	potion_button = button
	potion_count_label = count_label
	potion_icon = icon
	if potion_button and not potion_button.pressed.is_connected(_on_potion_pressed):
		potion_button.pressed.connect(_on_potion_pressed)
	_bind_game_state()
	refresh()

func bind_stats(stats: CharacterStats) -> void:
	if _bound_stats == stats:
		return
	if _bound_stats:
		if _bound_stats.hp_changed.is_connected(_on_hp_changed):
			_bound_stats.hp_changed.disconnect(_on_hp_changed)
		if _bound_stats.stats_changed.is_connected(refresh):
			_bound_stats.stats_changed.disconnect(refresh)
	
	_bound_stats = stats
	if _bound_stats:
		if not _bound_stats.hp_changed.is_connected(_on_hp_changed):
			_bound_stats.hp_changed.connect(_on_hp_changed)
		if not _bound_stats.stats_changed.is_connected(refresh):
			_bound_stats.stats_changed.connect(refresh)
	refresh()

func _on_hp_changed(_current: int, _max: int) -> void:
	refresh()

func _bind_game_state() -> void:
	_game_state_manager = get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if _game_state_manager and not _game_state_manager.state_changed.is_connected(_on_game_state_changed):
		_game_state_manager.state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(_new_state: GameStateManager.State, _old_state: GameStateManager.State) -> void:
	refresh()

func _on_potion_pressed() -> void:
	if not _can_use_potion_now():
		return
	if _bound_stats == null:
		var ps = get_node_or_null("/root/PlayerStats")
		if ps == null or ps.stats == null:
			return
		_bound_stats = ps.stats
	if _bound_stats == null:
		return
	_bound_stats.use_potion()

func _can_use_potion_now() -> bool:
	if _game_state_manager and not _game_state_manager.is_active():
		return false
	if _bound_stats == null:
		var ps = get_node_or_null("/root/PlayerStats")
		if ps == null or ps.stats == null:
			return false
		_bound_stats = ps.stats
	if _bound_stats == null:
		return false
	return _bound_stats.potions_owned > 0 and _bound_stats.current_hp < _bound_stats.max_hp

func refresh() -> void:
	var can_use := _can_use_potion_now()
	var owned := 0
	if _bound_stats:
		owned = _bound_stats.potions_owned
	else:
		var ps = get_node_or_null("/root/PlayerStats")
		if ps and ps.stats:
			_bound_stats = ps.stats
			owned = _bound_stats.potions_owned

	if potion_button:
		potion_button.disabled = not can_use
		potion_button.text = "Usar" if owned > 0 else "Usada"
	if potion_count_label:
		potion_count_label.text = "x%d" % owned
	if potion_icon:
		potion_icon.modulate = Color(1, 1, 1, 1) if owned > 0 else Color(0.5, 0.5, 0.5, 0.8)
