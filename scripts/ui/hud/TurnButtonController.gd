extends Node
class_name TurnButtonController

# Wires the "Pasar Turno" (End Turn) button to TurnManager.request_pass_turn,
# mirroring PotionController's setup/refresh pattern.

var turn_button: Button = null


func setup(button: Button) -> void:
	turn_button = button
	if turn_button and not turn_button.pressed.is_connected(_on_pressed):
		turn_button.pressed.connect(_on_pressed)
	refresh()

func _on_pressed() -> void:
	var player := Engine.get_main_loop().get_first_node_in_group("player") as PlayerMovement
	if player == null or player.turn_manager == null:
		return
	player.turn_manager.request_pass_turn(player)

func refresh() -> void:
	if turn_button == null:
		return
	var player := Engine.get_main_loop().get_first_node_in_group("player") as PlayerMovement
	turn_button.disabled = not (player != null and player.can_accept_input())
