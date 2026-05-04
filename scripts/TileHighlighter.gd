extends Node2D

@export var map_manager_path: NodePath
@onready var map_manager: MapManager = get_node(map_manager_path)

var hovered_cell: Vector2i = Vector2i(-999, -999)

func _ready():
	print("TileHighlighter READY")
	print("map_manager =", map_manager)
	map_manager.hover_changed.connect(_on_hover_changed)
	z_index = 999
	queue_redraw()
	set_process(true)

func _on_hover_changed(cell: Vector2i) -> void:
	hovered_cell = cell
	queue_redraw()

func _process(_delta):
	queue_redraw()

func _draw():
	if hovered_cell == Vector2i(-999, -999):
		return

	var tile_size = 16
	var pos = map_manager.grid_to_world_coords(hovered_cell)

	var half = tile_size / 2

	var top_left = pos - Vector2(tile_size, tile_size) * 0.5
	
	var rect = Rect2(
		top_left,
		Vector2(tile_size, tile_size)
	)

	draw_rect(rect, Color(0, 1, 0, 0.12), false, 2.0)
