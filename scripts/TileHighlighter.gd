extends Node2D

@export var map_manager_path: NodePath
@onready var map_manager: MapManager = get_node(map_manager_path)

var hovered_cell: Vector2i = Vector2i(-999, -999)
var _path_preview: Array[Vector2i] = []
var _last_hover_cell: Vector2i = Vector2i(-999, -999)

var _player: PlayerMovement = null
var _card_manager: CardManager = null

func _ready():
	print("TileHighlighter READY")
	print("map_manager =", map_manager)
	map_manager.hover_changed.connect(_on_hover_changed)
	z_index = 999
	queue_redraw()
	set_process(true)
	_resolve_refs()

func _on_hover_changed(cell: Vector2i) -> void:
	if not _can_update():
		_path_preview.clear()
		return
	hovered_cell = cell
	_update_path_preview()
	queue_redraw()

func _process(_delta):
	if not _can_update():
		_path_preview.clear()
		return
	if _player == null or _card_manager == null:
		_resolve_refs()
	queue_redraw()

func _draw():
	if hovered_cell == Vector2i(-999, -999):
		return

	var tile_size := _get_tile_size()
	var hovered_pos := map_manager.grid_to_world_coords(hovered_cell)
	var _half := tile_size * 0.5
	var top_left := hovered_pos - Vector2(tile_size, tile_size) * 0.5
	var rect := Rect2(top_left, Vector2(tile_size, tile_size))

	_draw_path_preview(tile_size)
	_draw_range_preview(tile_size)

	# Hovered destination
	draw_rect(rect, Color(0.9, 0.9, 0.9, 0.12), false, 2.0)

func _draw_path_preview(tile_size: float) -> void:
	if _path_preview.is_empty():
		return

	var last_center := Vector2.ZERO
	for i in range(_path_preview.size()):
		var cell := _path_preview[i]
		var world_pos := map_manager.grid_to_world_coords(cell)
		var rect := Rect2(world_pos - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
		draw_rect(rect, Color(0.9, 0.9, 0.9, 0.12), true)

		if i > 0:
			draw_line(last_center, world_pos, Color(0.9, 0.9, 0.9, 0.6), 2.0)
		last_center = world_pos

	if _path_preview.size() >= 2:
		var from_pos := map_manager.grid_to_world_coords(_path_preview[_path_preview.size() - 2])
		var to_pos := map_manager.grid_to_world_coords(_path_preview[_path_preview.size() - 1])
		_draw_arrow(from_pos, to_pos, Color(0.9, 0.9, 0.9, 0.75))

func _draw_range_preview(tile_size: float) -> void:
	if _player == null or _card_manager == null:
		return

	var card := _card_manager.get_active_card()
	if card == null:
		return
	if card.target_type != "enemy" or card.range <= 0:
		return

	var player_cell: Vector2i = _player.grid_pos
	var range_cells := CardTargeting.get_range_cells(player_cell, card.range, map_manager)
	for cell in range_cells:
		var world_pos := map_manager.grid_to_world_coords(cell)
		var rect := Rect2(world_pos - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.08), false, 1.0)

	var hover_actor := map_manager.get_actor_at_cell(hovered_cell)
	if hover_actor and hover_actor != _player:
		var in_range := CardTargeting.is_in_range(_player, hover_actor, card.range, map_manager)
		var hover_pos := map_manager.grid_to_world_coords(hovered_cell)
		var hover_rect := Rect2(hover_pos - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
		var color := Color(0.2, 1.0, 0.4, 0.18) if in_range else Color(1.0, 0.2, 0.2, 0.18)
		draw_rect(hover_rect, color, true)

func _draw_arrow(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var dir := (to_pos - from_pos).normalized()
	var tip := to_pos
	var left := tip - dir * 6.0 + Vector2(-dir.y, dir.x) * 4.0
	var right := tip - dir * 6.0 + Vector2(dir.y, -dir.x) * 4.0
	draw_line(tip, left, color, 2.0)
	draw_line(tip, right, color, 2.0)

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

	_path_preview = map_manager.find_path(_player.grid_pos, hovered_cell, _player)

func _get_tile_size() -> float:
	if map_manager and map_manager.dungeon_generator:
		return float(map_manager.dungeon_generator.tile_size)
	return 16.0

func _resolve_refs() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerMovement
	if _card_manager == null and _player:
		_card_manager = _player.get_node_or_null("CardManager") as CardManager

func _can_update() -> bool:
	var game_state_manager := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if game_state_manager:
		return game_state_manager.can_update_overlays()
	return true
