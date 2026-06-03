extends Node
class_name TileHighlighterRenderer

const INVALID_CELL := Vector2i(-999, -999)
const PULSE_SPEED := 0.006

func draw(
	canvas: Node2D,
	tile_size: float,
	path_preview: Array[Vector2i],
	cached_range: Array[Vector2i],
	hovered_cell: Vector2i,
	player: Node,
	map_manager: MapManager
) -> void:

	if hovered_cell == INVALID_CELL:
		return

	_draw_range_preview(
		canvas,
		tile_size,
		cached_range,
		hovered_cell,
		player,
		map_manager
	)

	_draw_path_preview(
		canvas,
		tile_size,
		path_preview,
		map_manager
	)

	_draw_hover(
		canvas,
		tile_size,
		hovered_cell,
		player,
		map_manager
	)


func _draw_hover(
	canvas: Node2D,
	tile_size: float,
	hovered_cell: Vector2i,
	player: Node,
	map_manager: MapManager
) -> void:

	var pos: Vector2 = map_manager.grid_to_world_coords(hovered_cell)

	var rect := Rect2(
		pos - Vector2.ONE * tile_size * 0.5,
		Vector2.ONE * tile_size
	)

	var walkable := true

	if player:
		walkable = map_manager.is_walkable_cell_for_actor(
			hovered_cell,
			player
		)

	var pulse := 0.75 + sin(Time.get_ticks_msec() * PULSE_SPEED) * 0.25

	var color: Color = ThemeManager.tactical_hover_border_color()

	if not walkable:
		color = QuestPalette.BLOOD_LIGHT

	color.a *= pulse

	canvas.draw_rect(
		rect,
		color,
		false,
		3.0
	)

	canvas.draw_rect(
		rect.grow(-2.0),
		color,
		false,
		1.0
	)


func _draw_range_preview(
	canvas: Node2D,
	tile_size: float,
	cached_range: Array[Vector2i],
	hovered_cell: Vector2i,
	player: Node,
	map_manager: MapManager
) -> void:

	for cell in cached_range:

		var pos: Vector2 = map_manager.grid_to_world_coords(cell)

		var rect := Rect2(
			pos - Vector2.ONE * tile_size * 0.5,
			Vector2.ONE * tile_size
		)

		canvas.draw_rect(
			rect,
			ThemeManager.tactical_range_border_color(),
			false,
			1.0
		)

	var actor: Node = map_manager.get_actor_at_cell(hovered_cell)

	if actor and actor != player:

		var pos: Vector2 = map_manager.grid_to_world_coords(
			hovered_cell
		)

		canvas.draw_arc(
			pos,
			tile_size * 0.40,
			0.0,
			TAU,
			32,
			ThemeManager.tactical_enemy_ring_color(),
			2.0
		)


func _draw_path_preview(
	canvas: Node2D,
	tile_size: float,
	path_preview: Array[Vector2i],
	map_manager: MapManager
) -> void:

	if path_preview.is_empty():
		return

	for i in range(path_preview.size()):

		var pos: Vector2 = map_manager.grid_to_world_coords(
			path_preview[i]
		)

        # For the last cell remove the circle 

        
		var color: Color = ThemeManager.tactical_path_dot_color()

		var radius := tile_size * 0.12

		if i == path_preview.size() - 1:
			color = ThemeManager.tactical_destination_color()
			radius = tile_size * 0.22

		canvas.draw_circle(
			pos,
			radius,
			color
		)

	if path_preview.size() >= 2:

		var from_pos: Vector2 = map_manager.grid_to_world_coords(
			path_preview[path_preview.size() - 2]
		)

		var to_pos: Vector2 = map_manager.grid_to_world_coords(
			path_preview[path_preview.size() - 1]
		)

		_draw_arrow(
			canvas,
			from_pos,
			to_pos
		)


func _draw_arrow(
	canvas: Node2D,
	from_pos: Vector2,
	to_pos: Vector2
) -> void:

	var dir := (to_pos - from_pos).normalized()

	var tip := to_pos

	var size := 4.0

	var left := (
		tip
		- dir * size
		+ Vector2(-dir.y, dir.x) * size
	)

	var right := (
		tip
		- dir * size
		+ Vector2(dir.y, -dir.x) * size
	)

	var color: Color = ThemeManager.tactical_destination_color()

	canvas.draw_line(
		tip,
		left,
		color,
		2.0
	)

	canvas.draw_line(
		tip,
		right,
		color,
		2.0
	)