extends Resource
class_name DungeonFloorThemeProfile

@export var main_tile: Vector2i = Vector2i(5, 10)
@export var tile_variations: Array[Vector2i] = [
	Vector2i(3, 10),
	Vector2i(10, 8),
	Vector2i(7, 10),
	Vector2i(1, 10),
	Vector2i(2, 10)
]
@export var edge_top_tile: Vector2i = Vector2i(5, 9)
@export var edge_top_right_tile: Vector2i = Vector2i(6, 9)
@export var edge_top_left_tile: Vector2i = Vector2i(4, 9)
@export var edge_bottom_tile: Vector2i = Vector2i(5, 11)
@export var edge_bottom_right_tile: Vector2i = Vector2i(6, 11)
@export var edge_bottom_left_tile: Vector2i = Vector2i(4, 11)
@export var edge_left_tile: Vector2i = Vector2i(4, 10)
@export var edge_right_tile: Vector2i = Vector2i(6, 10)
@export_range(0.0, 1.0, 0.01) var variation_chance: float = 0.3
