extends CharacterBody2D
class_name Enemy

signal enemy_defeated(enemy)

var my_room_id: int = -1
var dungeon_generator: Node = null

@onready var stats: CharacterStats = $Stats

var player: CharacterBody2D
var player_torch: PointLight2D

func _ready():
	stats.died.connect(_on_died)

func _on_died():
	enemy_defeated.emit(self)
	queue_free()

func apply_damage(amount: int):
	stats.current_hp -= amount
	if stats.current_hp <= 0:
		_on_died()
