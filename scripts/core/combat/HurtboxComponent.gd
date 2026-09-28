extends Area2D
class_name HurtboxComponent

## HurtboxComponent: passive "can be hit" area. Owns no HP — it only relays
## incoming damage via `hurt` so each entity keeps its own HP block
## (CharacterStats for the hero, Enemy.take_damage for enemies). The owner
## connects `hurt` in its own _ready(). Which HitboxComponents can reach it is
## decided purely by physics layers (see project.godot [layer_names]).

signal hurt(amount: int)


func _ready() -> void:
	monitoring = false
	monitorable = true
	input_pickable = false


func receive_hit(amount: int) -> void:
	if amount > 0:
		hurt.emit(amount)
