extends Resource
class_name DungeonGenerationConfig

@export var grid_width: int = 90
@export var grid_height: int = 70
@export var tile_size: float = 16.0
@export var room_count: int = 8
@export var room_min_size: Vector2i = Vector2i(10, 8)
@export var room_max_size: Vector2i = Vector2i(20, 14)
@export var room_padding: int = 4
@export var room_light_energy: float = 0.0
@export var room_light_transition_seconds: float = 0.45
@export var corridor_min_length: int = 4
@export var corridor_max_length: int = 8
@export var map_seed: int = -1
