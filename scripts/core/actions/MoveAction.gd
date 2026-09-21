extends BaseAction
class_name MoveAction

## MoveAction: tweens `owner` (a Player) step-by-step along a BFS-built path,
## spending 1 or 2 AP depending on which zone was clicked. Does not force
## the turn to end (consume_turn = false) — TurnManager ends it only once
## AP is fully spent, letting the player chain a second move in the same turn.

const STEP_DURATION := 0.15

var path: Array[Vector2i] = []
var tilemap: TileMapLayer = null


func _init(p_owner: Node = null, p_path: Array[Vector2i] = [], p_tilemap: TileMapLayer = null, p_ap_cost: int = 1) -> void:
	super._init(p_owner, p_path)
	path = p_path
	tilemap = p_tilemap
	ap_cost = p_ap_cost
	consume_turn = false


func can_execute() -> bool:
	return owner != null and "stats" in owner and owner.stats != null \
		and owner.stats.has_ap(ap_cost) and path.size() > 1 and tilemap != null


func get_failure_reason() -> String:
	return "insufficient_ap_or_invalid_path"


func execute() -> void:
	if not owner.stats.spend_ap(ap_cost):
		finish({"status": "failed_spend_ap", "consumes_turn": false})
		return

	for cell in path.slice(1):
		var target_world: Vector2 = GridUtils.cell_to_world(tilemap, cell)
		var tw := owner.create_tween()
		tw.tween_property(owner, "global_position", target_world, STEP_DURATION)
		await tw.finished

	owner.grid_pos = path[-1]
	finish({"status": "ok", "consumes_turn": false})
