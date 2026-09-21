extends Node2D
class_name PlayerActionController

## PlayerActionController: two-click move confirmation over the BFS movement
## range from MapNavigationHelper. Hover previews the path + AP cost; first
## click locks a target; second click on the same cell executes the move as
## a MoveAction; right-click cancels at any point.

const HIGHLIGHT_SOURCE_ID := 0
const BLUE_ATLAS := Vector2i(0, 0)
const AMBER_ATLAS := Vector2i(1, 0)
const PATH_ATLAS := Vector2i(2, 0)
const NO_SELECTION := Vector2i(999999, 999999)
const NO_HOVER := Vector2i(-999999, -999999)

var player: Player
var tilemap: TileMapLayer
var highlight_layer: TileMapLayer
var ap_label: Label
var turn_manager: TurnManager

var _zones: Dictionary = {}          # Vector2i -> ap_cost
var _came_from: Dictionary = {}
var _current_path_cells: Array[Vector2i] = []
var _selected_cell: Vector2i = NO_SELECTION
var _hover_cell: Vector2i = NO_HOVER
var _action_in_flight: bool = false


func setup(p_player: Player, p_tilemap: TileMapLayer, p_highlight_layer: TileMapLayer,
		p_ap_label: Label, p_turn_manager: TurnManager) -> void:
	player = p_player
	tilemap = p_tilemap
	highlight_layer = p_highlight_layer
	ap_label = p_ap_label
	turn_manager = p_turn_manager

	if turn_manager and not turn_manager.actor_turn_changed.is_connected(_on_actor_turn_changed):
		turn_manager.actor_turn_changed.connect(_on_actor_turn_changed)
	if player and player.stats and not player.stats.ap_changed.is_connected(_on_ap_changed):
		player.stats.ap_changed.connect(_on_ap_changed)

	_hide_ap_label()
	_refresh_zones()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_act():
		return

	if event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_selection()
			get_viewport().set_input_as_handled()


func _can_act() -> bool:
	return player != null and tilemap != null and highlight_layer != null \
		and turn_manager != null and turn_manager.current_actor == player \
		and player.can_accept_input() and not _action_in_flight


# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
func _on_actor_turn_changed(actor: Node) -> void:
	_cancel_selection()
	if actor == player:
		_refresh_zones()
	else:
		_zones = {}
		_came_from = {}
		_clear_highlights()


func _on_ap_changed(_current: int, _max: int) -> void:
	_cancel_selection()
	_refresh_zones()


func _on_move_completed(_action: BaseAction, _result: Dictionary) -> void:
	_action_in_flight = false
	_refresh_zones()


# ─────────────────────────────────────────────
# ZONE COMPUTATION / RENDERING
# ─────────────────────────────────────────────
func _refresh_zones() -> void:
	_zones = {}
	_came_from = {}
	_clear_highlights()

	if player == null or tilemap == null or player.stats == null:
		return
	if turn_manager == null or turn_manager.current_actor != player:
		return

	var result := MapNavigationHelper.compute_movement_range(
		player.grid_pos, player.stats.current_ap, player.stats.move_range_per_ap,
		Callable(self, "_is_cell_walkable")
	)
	_zones = result["cells"]
	_came_from = result["came_from"]
	_draw_zone_highlights()


func _is_cell_walkable(cell: Vector2i) -> bool:
	return tilemap.get_cell_source_id(cell) != -1


func _draw_zone_highlights() -> void:
	if highlight_layer == null:
		return
	highlight_layer.clear()
	for cell in _zones.keys():
		var atlas := BLUE_ATLAS if _zones[cell] == 1 else AMBER_ATLAS
		highlight_layer.set_cell(cell, HIGHLIGHT_SOURCE_ID, atlas)
	_current_path_cells = []


func _clear_highlights() -> void:
	if highlight_layer:
		highlight_layer.clear()
	_current_path_cells = []


func _set_path_preview(path: Array[Vector2i]) -> void:
	for cell in _current_path_cells:
		if _zones.has(cell):
			var atlas := BLUE_ATLAS if _zones[cell] == 1 else AMBER_ATLAS
			highlight_layer.set_cell(cell, HIGHLIGHT_SOURCE_ID, atlas)
		else:
			highlight_layer.erase_cell(cell)

	_current_path_cells = []
	for cell in path:
		if player and cell == player.grid_pos:
			continue
		highlight_layer.set_cell(cell, HIGHLIGHT_SOURCE_ID, PATH_ATLAS)
		_current_path_cells.append(cell)


# ─────────────────────────────────────────────
# INPUT STATE MACHINE
# ─────────────────────────────────────────────
func _update_hover(mouse_global_pos: Vector2) -> void:
	var cell := GridUtils.world_to_cell(tilemap, mouse_global_pos)
	if cell == _hover_cell:
		return
	_hover_cell = cell

	if _selected_cell != NO_SELECTION:
		return   # locked-in preview stays until confirmed/re-aimed/cancelled

	if _zones.has(cell):
		var path := MapNavigationHelper.build_path(_came_from, player.grid_pos, cell)
		_set_path_preview(path)
		_show_ap_label(cell, _zones[cell])
	else:
		_set_path_preview([])
		_hide_ap_label()


func _handle_left_click(mouse_global_pos: Vector2) -> void:
	var cell := GridUtils.world_to_cell(tilemap, mouse_global_pos)
	if not _zones.has(cell):
		return

	if _selected_cell == cell:
		_confirm_move(cell)
		return

	_selected_cell = cell
	var path := MapNavigationHelper.build_path(_came_from, player.grid_pos, cell)
	_set_path_preview(path)
	_show_ap_label(cell, _zones[cell])


func _confirm_move(target_cell: Vector2i) -> void:
	var path := MapNavigationHelper.build_path(_came_from, player.grid_pos, target_cell)
	if path.is_empty() or not _zones.has(target_cell):
		_cancel_selection()
		return

	var ap_cost: int = _zones[target_cell]
	var move_action := MoveAction.new(player, path, tilemap, ap_cost)
	move_action.completed.connect(_on_move_completed, CONNECT_ONE_SHOT)

	_action_in_flight = true
	_selected_cell = NO_SELECTION
	_clear_highlights()
	_hide_ap_label()

	turn_manager.action_queue.queue_action(move_action)


func _cancel_selection() -> void:
	if _selected_cell == NO_SELECTION:
		return
	_selected_cell = NO_SELECTION
	_set_path_preview([])
	_hide_ap_label()


func _show_ap_label(cell: Vector2i, ap_cost: int) -> void:
	if ap_label == null:
		return
	ap_label.text = "-%d AP" % ap_cost
	ap_label.global_position = GridUtils.cell_to_world(tilemap, cell) + Vector2(-16, -48)
	ap_label.visible = true


func _hide_ap_label() -> void:
	if ap_label:
		ap_label.visible = false
