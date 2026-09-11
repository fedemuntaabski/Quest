extends RefCounted
class_name MenuTransitionFX

## Shared fade + scale entrance/exit tween builder for BaseMenu/BaseSubPanel.
## `owner` must be a Node (needed for create_tween()); this class only configures tweens.

static func play_entrance(owner: Node, fade_targets: Array[Dictionary], scale_targets: Array[CanvasItem],
		duration: float, trans: Tween.TransitionType, ease: Tween.EaseType, from_scale: Vector2) -> Tween:
	if fade_targets.is_empty() and scale_targets.is_empty():
		return null

	var tw: Tween = owner.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	for entry in fade_targets:
		var node: CanvasItem = entry["node"]
		node.modulate.a = 0.0
		tw.tween_property(node, "modulate:a", entry["max_alpha"], duration)

	for node in scale_targets:
		if node is Control:
			(node as Control).pivot_offset = (node as Control).size * 0.5
		node.scale = from_scale
		tw.tween_property(node, "scale", Vector2.ONE, duration).set_trans(trans).set_ease(ease)

	return tw


static func play_exit(owner: Node, fade_targets: Array[Dictionary], scale_targets: Array[CanvasItem],
		duration: float, to_scale: Vector2) -> Tween:
	if fade_targets.is_empty() and scale_targets.is_empty():
		return null

	var tw: Tween = owner.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	for entry in fade_targets:
		tw.tween_property(entry["node"], "modulate:a", 0.0, duration)

	for node in scale_targets:
		tw.tween_property(node, "scale", to_scale, duration)

	return tw
