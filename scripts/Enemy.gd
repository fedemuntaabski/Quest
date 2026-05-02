extends CharacterBody2D
class_name Enemy

var my_room_id: int = -1
var dungeon_generator: Node = null

@onready var stats: CharacterStats = $Stats

var player: CharacterBody2D
var player_torch: PointLight2D


