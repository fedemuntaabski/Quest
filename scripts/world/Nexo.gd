extends Area2D
class_name Nexo

## Nexo: clickable pickup in the start room (just above its center). Click
## plumbing mirrors Door.gd. NexoController owns the pickup rule (exit room
## discovered + hero in the start room), the confirmation dialog and the
## extraction kick-off.

signal nexo_clicked(nexo: Nexo)

## Raiders (Enemy.Role RAIDER) wear this down; 0 = the defeat condition.
@export var max_hp: int = 100

var current_hp: int = 100
var _picked_up: bool = false


func _ready() -> void:
	add_to_group("nexo")
	current_hp = max_hp
	z_index = 2
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _picked_up:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	nexo_clicked.emit(self)
	get_viewport().set_input_as_handled()


func take_damage(amount: int) -> void:
	if current_hp <= 0:
		return
	current_hp = maxi(current_hp - maxi(amount, 0), 0)


func is_alive() -> bool:
	return current_hp > 0


## The hero carrying it, or null while it sits in the start room.
func get_carrier() -> Player:
	for hero in ManagerLocator.get_heroes():
		if hero.is_carrying_nexo:
			return hero
	return null


## Where raiders must go: the carrier once picked up, else the start-room spot.
func get_target_position() -> Vector2:
	var carrier := get_carrier()
	return carrier.global_position if carrier else global_position


func get_target_zone(room_manager: RoomManager) -> String:
	var carrier := get_carrier()
	return carrier.current_zone_id if carrier else room_manager.get_start_zone_id()


func pick_up() -> void:
	_picked_up = true
	visible = false
	input_pickable = false
