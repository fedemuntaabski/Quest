extends Node2D
class_name Player

## Player: test-scene actor. Owns a CharacterStats component and a grid cell
## position. Moves freely — no turn/AP gating.

@onready var stats: CharacterStats = $Stats
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var character_data: CharacterData = null
var current_zone_id: String = ""
var is_carrying_relic: bool = false

## grid_pos is the cell under the hero's world position — debug/logging only.
## Movement, door access and reachability all key off current_zone_id.
var grid_pos: Vector2i = Vector2i.ZERO


func configure(data: CharacterData) -> void:
	# Called before add_child(); @onready vars aren't valid yet, so just stash
	# the reference — actual visual application happens in _ready().
	character_data = data


func _ready() -> void:
	add_to_group("player")
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.register(stats)
	if character_data:
		_apply_character_visuals(character_data)


func _apply_character_visuals(data: CharacterData) -> void:
	if data.sprite_frames and animated_sprite:
		animated_sprite.sprite_frames = data.sprite_frames
		if data.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")


func set_grid_position(cell: Vector2i, tilemap: TileMapLayer) -> void:
	grid_pos = cell
	global_position = GridUtils.cell_to_world(tilemap, cell)


func set_zone(zone_id: String, center: Vector2, tilemap: TileMapLayer) -> void:
	current_zone_id = zone_id
	global_position = center
	grid_pos = GridUtils.world_to_cell(tilemap, center)


func can_accept_input() -> bool:
	return stats != null and stats.is_alive()


func pick_up_relic() -> void:
	is_carrying_relic = true
