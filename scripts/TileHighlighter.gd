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

const COLOR_RANGE_FILL := Color(1.0, 0.2, 0.2, 0.18)
const COLOR_RANGE_BORDER := Color(1.0, 0.35, 0.35, 0.95)
const COLOR_RANGE_INNER := Color(1.0, 0.7, 0.7, 0.18)

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
var _last_player_grid_pos: Vector2i = INVALID_CELL
var _renderer: TileHighlighterRenderer = null
var _cache: TileHighlighterCache = null

# =====================================================
# READY
# =====================================================

func _ready() -> void:
	z_index = 999

	_resolve_refs()

	# Initialize renderer for drawing routines
	_renderer = preload("res://scripts/tile_highlighter/TileHighlighterRenderer.gd").new()

	# Cache helper for range calculations
	_cache = preload("res://scripts/tile_highlighter/TileHighlighterCache.gd").new()

	if map_manager:
		map_manager.hover_changed.connect(_on_hover_changed)

	_connect_player_signals()
	queue_redraw()

# =====================================================
# PLAYER MOVEMENT & STATE SIGNALS
# =====================================================

func _connect_player_signals() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerMovement
	
	if _player == null:
		call_deferred("_connect_player_signals")
		return
	
	# Connect to game state changes to clear overlays when state changes
	var gsm := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if gsm and not gsm.state_changed.is_connected(_on_game_state_changed):
		gsm.state_changed.connect(_on_game_state_changed)

	if _card_manager and not _card_manager.active_index_changed.is_connected(_on_active_index_changed):
		_card_manager.active_index_changed.connect(_on_active_index_changed)

func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	# Clear range grid when game state changes (e.g., combat ends, turn ends)
	if new_state != GameStateManager.State.ACTIVE:
		_cached_range_cells.clear()
		queue_redraw()

func _on_active_index_changed(_index: int) -> void:
	_cached_range_cells.clear()
	_last_active_card = null
	queue_redraw()

# =====================================================
# PROCESS
# =====================================================

func _process(_delta: float) -> void:
	if _player == null or _card_manager == null:
		_resolve_refs()

	# Clear range grid if player moved
	if _player and _player.grid_pos != _last_player_grid_pos:
		_last_player_grid_pos = _player.grid_pos
		if not _cached_range_cells.is_empty():
			_cached_range_cells.clear()
			queue_redraw()

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

	if _renderer:
		_renderer.draw(self, tile_size, _path_preview, _cached_range_cells, hovered_cell, _player, map_manager)

# Drawing moved to TileHighlighterRenderer

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
	if _cache:
		_cache.update_range_cache(self)

# =====================================================
# HELPERS
# =====================================================

func _resolve_refs() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerMovement

	if _card_manager == null and _player:
		_card_manager = _player.get_node_or_null("CardManager") as CardManager
		if _card_manager and not _card_manager.active_index_changed.is_connected(_on_active_index_changed):
			_card_manager.active_index_changed.connect(_on_active_index_changed)

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