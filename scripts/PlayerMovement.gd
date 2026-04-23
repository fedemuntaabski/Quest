extends CharacterBody2D

class_name PlayerMovement

@export var SPEED: float = 360.0

func _physics_process(_delta: float) -> void:
	# Top-down movement using project input actions (WASD).
	var input_direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_direction != Vector2.ZERO:
		velocity = input_direction.normalized() * SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if is_on_wall() and get_slide_collision_count() > 0:
		var wall_collision := get_last_slide_collision()
		if wall_collision:
			velocity = velocity.slide(wall_collision.get_normal())
