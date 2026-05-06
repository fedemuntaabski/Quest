extends CharacterBody2D
class_name Enemy

signal enemy_defeated(enemy)

var map_manager: MapManager
var player: PlayerMovement
var grid_pos: Vector2i
var player_torch: PointLight2D 
var my_room_id: int = -1
var dungeon_generator: DungeonGenerator

@onready var stats: CharacterStats = $Stats

func _ready():
	stats.died.connect(_on_died)

func setup(p_map: MapManager, p_player: PlayerMovement):
	map_manager = p_map
	player = p_player
	sync_to_grid()

func sync_to_grid():
	if map_manager:
		grid_pos = map_manager.world_to_grid_coords(global_position)

func take_turn(turn_manager):
	if map_manager == null or player == null:
		turn_manager.end_turn()
		return

	sync_to_grid()

	var path: Array[Vector2i] = map_manager.find_path(grid_pos, player.grid_pos)

	if path.size() > 1:
		var next_cell = path[1]
		grid_pos = next_cell
		global_position = map_manager.grid_to_world_coords(next_cell)

	# después vemos ataque, por ahora solo movimiento
	await get_tree().create_timer(0.1).timeout

	turn_manager.end_turn()


func _on_died():
	enemy_defeated.emit(self)
	queue_free()