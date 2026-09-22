extends BaseAction
class_name MoveAction

## MoveAction: glides `owner` along a chain of world-space waypoints (room/
## corridor centers) with a single continuous Tween — no per-cell movement,
## no AP cost, no turn consumption.

const DEFAULT_SPEED_PX := 420.0
const MIN_STEP_DURATION := 0.10

var waypoints: Array[Vector2] = []
var speed: float = DEFAULT_SPEED_PX


func _init(p_owner: Node = null, p_waypoints: Array[Vector2] = [], p_speed: float = DEFAULT_SPEED_PX) -> void:
	super._init(p_owner, p_waypoints)
	waypoints = p_waypoints
	speed = p_speed


func can_execute() -> bool:
	return owner != null and not waypoints.is_empty()


func execute() -> void:
	var tw := owner.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var from: Vector2 = owner.global_position
	for waypoint in waypoints:
		var step_duration := maxf(MIN_STEP_DURATION, from.distance_to(waypoint) / speed)
		tw.tween_property(owner, "global_position", waypoint, step_duration)
		from = waypoint

	await tw.finished
	finish({"status": "ok", "position": owner.global_position})
