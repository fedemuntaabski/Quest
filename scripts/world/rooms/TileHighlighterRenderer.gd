extends Node
class_name TileHighlighterRenderer

# Renderer helpers for TileHighlighter. These functions perform drawing
# operations on the provided `owner` (a TileHighlighter Node2D instance).

func draw(canvas: Node2D, tile_size: float, path_preview: Array[Vector2i], cached_range: Array[Vector2i], hovered_cell: Vector2i, player: Node, map_manager: MapManager) -> void:
    if hovered_cell == Vector2i(-999, -999):
        return

    _draw_range_preview(canvas, tile_size, cached_range, hovered_cell, player, map_manager)
    _draw_path_preview(canvas, tile_size, path_preview, map_manager)
    _draw_hover(canvas, tile_size, hovered_cell, player, map_manager)


func _draw_hover(canvas: Node2D, tile_size: float, hovered_cell: Vector2i, player: Node, map_manager: MapManager) -> void:
    var hover_pos: Vector2 = map_manager.grid_to_world_coords(hovered_cell)

    var rect := Rect2(
        hover_pos - Vector2.ONE * tile_size * 0.5,
        Vector2.ONE * tile_size
    )

    var color := Color(0.25, 1.0, 0.45, 0.20)

    if player and not map_manager.is_walkable_cell_for_actor(hovered_cell, player):
        color = Color(1.0, 0.25, 0.25, 0.20)

    canvas.draw_rect(rect, color, true)
    canvas.draw_rect(rect, color.lightened(0.3), false, 2.0)


func _draw_path_preview(canvas: Node2D, tile_size: float, path_preview: Array[Vector2i], map_manager: MapManager) -> void:
    if path_preview.is_empty():
        return

    var previous_pos := Vector2.ZERO

    for i in range(path_preview.size()):
        var cell: Vector2i = path_preview[i]
        var world_pos: Vector2 = map_manager.grid_to_world_coords(cell)

        var rect := Rect2(
            world_pos - Vector2.ONE * tile_size * 0.5,
            Vector2.ONE * tile_size
        )

        var alpha = lerp(0.06, 0.18, float(i) / max(1.0, path_preview.size() - 1))

        var fill_color := Color(0.85, 0.85, 0.9, 0.10)
        fill_color.a = alpha

        canvas.draw_rect(rect, fill_color, true)
        canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.22), false, 1.0)

        if i > 0:
            canvas.draw_line(previous_pos, world_pos, Color(1.0, 1.0, 1.0, 0.55), 2.0, true)

        previous_pos = world_pos

    if path_preview.size() >= 2:
        var from_pos: Vector2 = map_manager.grid_to_world_coords(path_preview[path_preview.size() - 2])
        var to_pos: Vector2 = map_manager.grid_to_world_coords(path_preview[path_preview.size() - 1])
        _draw_arrow(canvas, from_pos, to_pos)


func _draw_range_preview(canvas: Node2D, tile_size: float, cached_range: Array[Vector2i], hovered_cell: Vector2i, player: Node, map_manager: MapManager) -> void:
    if cached_range.is_empty():
        return

    for cell in cached_range:
        var world_pos: Vector2 = map_manager.grid_to_world_coords(cell)
        var rect := Rect2(
            world_pos - Vector2.ONE * tile_size * 0.5,
            Vector2.ONE * tile_size
        )
        canvas.draw_rect(rect, Color(1.0, 0.2, 0.2, 0.18), true)
        canvas.draw_rect(rect, Color(1.0, 0.35, 0.35, 0.95), false, 2.0)
        canvas.draw_rect(rect.grow(-2.0), Color(1.0, 0.7, 0.7, 0.18), false, 1.0)

    var hover_actor: Node = map_manager.get_actor_at_cell(hovered_cell)
    if hover_actor and hover_actor != player:
        var in_range := hovered_cell in cached_range
        var hover_pos: Vector2 = map_manager.grid_to_world_coords(hovered_cell)
        var hover_rect := Rect2(
            hover_pos - Vector2.ONE * tile_size * 0.5,
            Vector2.ONE * tile_size
        )
        var color = Color(0.25, 1.0, 0.45, 0.20) if in_range else Color(1.0, 0.25, 0.25, 0.20)
        canvas.draw_rect(hover_rect, color, true)


func _draw_arrow(canvas: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
    var dir := (to_pos - from_pos).normalized()
    var tip := to_pos
    var arrow_size := 6.0
    var left := (tip - dir * arrow_size + Vector2(-dir.y, dir.x) * (arrow_size * 0.7))
    var right := (tip - dir * arrow_size + Vector2(dir.y, -dir.x) * (arrow_size * 0.7))
    canvas.draw_line(tip, left, Color(1.0, 1.0, 1.0, 0.85), 2.0, true)
    canvas.draw_line(tip, right, Color(1.0, 1.0, 1.0, 0.85), 2.0, true)
