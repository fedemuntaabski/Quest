extends Node2D
class_name TestGrid

## TestGrid: draws a plain reference grid for the empty gameplay test scene.
## No logic, no input — purely visual scaffolding.

@export var cell_size: float = 64.0
@export var half_extent: int = 10
@export var line_color: Color = Color(1, 1, 1, 0.12)
@export var origin_color: Color = Color(1, 1, 1, 0.35)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var extent := half_extent * cell_size

	var i := -half_extent
	while i <= half_extent:
		var offset := i * cell_size
		draw_line(Vector2(offset, -extent), Vector2(offset, extent), line_color)
		draw_line(Vector2(-extent, offset), Vector2(extent, offset), line_color)
		i += 1

	draw_line(Vector2(-extent, 0), Vector2(extent, 0), origin_color)
	draw_line(Vector2(0, -extent), Vector2(0, extent), origin_color)
