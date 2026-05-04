extends Node
class_name PlayerActionController

var player: CharacterBody2D
var map_manager: MapManager
var selected_target: Enemy = null

func setup(p_player: CharacterBody2D, p_map_manager: MapManager):
	player = p_player
	map_manager = p_map_manager

func get_action() -> Dictionary:
	var dir = Vector2i.ZERO

	if Input.is_action_just_pressed("ui_up"):
		dir = Vector2i.UP
	elif Input.is_action_just_pressed("ui_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_just_pressed("ui_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_just_pressed("ui_right"):
		dir = Vector2i.RIGHT

	if dir != Vector2i.ZERO:
		return {
			"type": "move",
			"move": dir,
			"name": "player_move"
		}

	if Input.is_action_just_pressed("attack"):
		return {
			"type": "attack",
			"name": "player_attack"
		}

	return {"type": "idle"}