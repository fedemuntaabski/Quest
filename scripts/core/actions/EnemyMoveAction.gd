extends BaseAction
class_name EnemyMoveAction

## EnemyMoveAction: glides an Enemy along a chain of world-space waypoints,
## same shape as MoveAction, but re-reads Enemy.current_speed() before each
## leg (so a Trap-applied slow takes effect on the next leg) and updates
## Enemy.current_zone_id to `final_zone_id` on completion.

const MIN_STEP_DURATION := 0.10

var waypoints: Array[Vector2] = []
var zone_ids: Array[String] = []
var enemy: Enemy


## `p_zone_ids[i]` is the zone reached at `p_waypoints[i]`; the enemy's
## current_zone_id is updated per leg so it can react (aggro) mid-path.
func _init(p_enemy: Enemy = null, p_waypoints: Array[Vector2] = [], p_zone_ids: Array[String] = []) -> void:
	super._init(p_enemy, p_waypoints)
	enemy = p_enemy
	waypoints = p_waypoints
	zone_ids = p_zone_ids


func can_execute() -> bool:
	return enemy != null and not waypoints.is_empty()


func execute() -> void:
	var from: Vector2 = enemy.global_position
	for i in range(waypoints.size()):
		var waypoint := waypoints[i]
		var speed := enemy.current_speed()
		var step_duration := maxf(MIN_STEP_DURATION, from.distance_to(waypoint) / speed)

		var tw := enemy.create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(enemy, "global_position", waypoint, step_duration)
		await tw.finished
		if not is_instance_valid(enemy):
			return

		from = waypoint
		if i < zone_ids.size():
			enemy.current_zone_id = zone_ids[i]
			enemy.on_zone_entered(zone_ids[i])
			if enemy.current_state == Enemy.State.ATTACKING:
				break

	finish({"status": "ok", "position": enemy.global_position})
