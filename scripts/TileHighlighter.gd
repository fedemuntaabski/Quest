extends Node2D
class_name TileHighlighter

# =====================================================
# CONFIG
# =====================================================

const INVALID_CELL := Vector2i(-999, -999)

const COLOR_PATH_FILL := Color(0.85, 0.85, 0.9, 0.10)
const COLOR_PATH_BORDER := Color(1.0, 1.0, 1.0, 0.22)

const COLOR_VALID := Color(0.25, 1.0, 0.45, 0.20)
const COLOR_INVALID := Color(1.0, 0.25, 0.25, 0.20)

const COLOR_RANGE := Color(1.0, 0.2, 0.2, 0.06)

const COLOR_LINE := Color(1.0, 1.0, 1.0, 0.55)
const COLOR_ARROW := Color(1.0, 1.0, 1.0, 0.85)

const PATH_LINE_WIDTH := 2.0
const HOVER_BORDER_WIDTH := 2.0

# =====================================================
# REFERENCES
# =====================================================

@export var map_manager_path: NodePath

@onready var map_manager: MapManager = get_node(map_manager_path)

var _player: PlayerMovement
var _card_manager: CardManager

# =====================================================
# STATE
# =====================================================

var hovered_cell: Vector2i = INVALID_CELL
var _last_hover_cell: Vector2i = INVALID_CELL

var _path_preview: Array[Vector2i] = []
var _cached_range_cells: Array[Vector2i] = []

var _last_active_card = null

# =====================================================
# READY
# =====================================================

func _ready() -> void:
	z_index = 999

	_resolve_refs()

	if map_manager:
		map_manager.hover_changed.connect(_on_hover_changed)

	queue_redraw()

# =====================================================
# PROCESS
# =====================================================

func _process(_delta: float) -> void:
	if _player == null or _card_manager == null:
		_resolve_refs()

	_update_range_cache_if_needed()

# =====================================================
# DRAW
# =====================================================

func _draw() -> void:
	if not _can_update():
		return

	if hovered_cell == INVALID_CELL:
		return

	var tile_size := _get_tile_size()

	_draw_range_preview(tile_size)
	_draw_path_preview(tile_size)
	_draw_hover(tile_size)

# =====================================================
# HOVER
# =====================================================

func _draw_hover(tile_size: float) -> void:
	var hover_pos := map_manager.grid_to_world_coords(hovered_cell)

	var rect := Rect2(
		hover_pos - Vector2.ONE * tile_size * 0.5,
		Vector2.ONE * tile_size
	)

	var color := COLOR_VALID

	if _player and not map_manager.is_walkable_cell_for_actor(hovered_cell, _player):
		color = COLOR_INVALID

	draw_rect(rect, color, true)
	draw_rect(rect, color.lightened(0.3), false, HOVER_BORDER_WIDTH)

# =====================================================
# PATH
# =====================================================

func _draw_path_preview(tile_size: float) -> void:
	if _path_preview.is_empty():
		return

	var previous_pos := Vector2.ZERO

	for i in range(_path_preview.size()):
		var cell := _path_preview[i]

		var world_pos := map_manager.grid_to_world_coords(cell)

		var rect := Rect2(
			world_pos - Vector2.ONE * tile_size * 0.5,
			Vector2.ONE * tile_size
		)

		var alpha = lerp(
	0.06,
	0.18,
	float(i) / max(1.0, _path_preview.size() - 1)
)

		var fill_color := COLOR_PATH_FILL
		fill_color.a = alpha

		draw_rect(rect, fill_color, true)
		draw_rect(rect, COLOR_PATH_BORDER, false, 1.0)

		if i > 0:
			draw_line(
				previous_pos,
				world_pos,
				COLOR_LINE,
				PATH_LINE_WIDTH,
				true
			)

		previous_pos = world_pos

	if _path_preview.size() >= 2:
		var from_pos := map_manager.grid_to_world_coords(
			_path_preview[_path_preview.size() - 2]
		)

		var to_pos := map_manager.grid_to_world_coords(
			_path_preview[_path_preview.size() - 1]
		)

		_draw_arrow(from_pos, to_pos)

# =====================================================
# RANGE
# =====================================================

func _draw_range_preview(tile_size: float) -> void:
	if _cached_range_cells.is_empty():
		return

	for cell in _cached_range_cells:
		var world_pos := map_manager.grid_to_world_coords(cell)

		var rect := Rect2(
			world_pos - Vector2.ONE * tile_size * 0.5,
			Vector2.ONE * tile_size
		)

		draw_rect(rect, COLOR_RANGE, false, 1.0)

	var hover_actor := map_manager.get_actor_at_cell(hovered_cell)

	if hover_actor and hover_actor != _player:
		var in_range := hovered_cell in _cached_range_cells

		var hover_pos := map_manager.grid_to_world_coords(hovered_cell)

		var hover_rect := Rect2(
			hover_pos - Vector2.ONE * tile_size * 0.5,
			Vector2.ONE * tile_size
		)

		var color = COLOR_VALID if in_range else COLOR_INVALID

		draw_rect(hover_rect, color, true)

# =====================================================
# ARROW
# =====================================================

func _draw_arrow(from_pos: Vector2, to_pos: Vector2) -> void:
	var dir := (to_pos - from_pos).normalized()

	var tip := to_pos

	var arrow_size := 6.0

	var left := (
		tip
		- dir * arrow_size
		+ Vector2(-dir.y, dir.x) * (arrow_size * 0.7)
	)

	var right := (
		tip
		- dir * arrow_size
		+ Vector2(dir.y, -dir.x) * (arrow_size * 0.7)
	)

	draw_line(tip, left, COLOR_ARROW, 2.0, true)
	draw_line(tip, right, COLOR_ARROW, 2.0, true)

# =====================================================
# PATH UPDATE
# =====================================================

func _on_hover_changed(cell: Vector2i) -> void:
	if not _can_update():
		return

	if hovered_cell == cell:
		return

	hovered_cell = cell

	_update_path_preview()

	queue_redraw()

func _update_path_preview() -> void:
	if map_manager == null or _player == null:
		_path_preview.clear()
		return

	if hovered_cell == _last_hover_cell:
		return

	_last_hover_cell = hovered_cell

	if hovered_cell == _player.grid_pos:
		_path_preview.clear()
		return

	if not map_manager.is_within_bounds(hovered_cell):
		_path_preview.clear()
		return

	if not map_manager.is_walkable_cell_for_actor(hovered_cell, _player):
		_path_preview.clear()
		return

	_path_preview = map_manager.find_path(
		_player.grid_pos,
		hovered_cell,
		_player
	)

# =====================================================
# RANGE CACHE
# =====================================================

func _update_range_cache_if_needed() -> void:
	if _player == null or _card_manager == null:
		return

	var card = _card_manager.get_active_card()

	if card == _last_active_card:
		return

	_last_active_card = card
	_cached_range_cells.clear()

	if card == null:
		queue_redraw()
		return

	if card.target_type != "enemy":
		queue_redraw()
		return

	if card.range <= 0:
		queue_redraw()
		return

	_cached_range_cells = CardTargeting.get_range_cells(
		_player.grid_pos,
		card.range,
		map_manager
	)

	queue_redraw()

# =====================================================
# HELPERS
# =====================================================

func _resolve_refs() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerMovement

	if _card_manager == null and _player:
		_card_manager = _player.get_node_or_null("CardManager") as CardManager

func _get_tile_size() -> float:
	if map_manager and map_manager.dungeon_generator:
		return float(map_manager.dungeon_generator.tile_size)

	return 16.0

func _can_update() -> bool:
	var gsm := get_tree().get_first_node_in_group(
		"game_state_manager"
	) as GameStateManager

	if gsm:
		return gsm.can_update_overlays()

	return true