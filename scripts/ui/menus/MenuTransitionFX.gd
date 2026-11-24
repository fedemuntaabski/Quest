extends RefCounted
class_name MenuTransitionFX

## Shared fade + scale entrance/exit tween builders for the menus.
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
		duration: float, to_scale: Vector2,
		trans: Tween.TransitionType = Tween.TRANS_LINEAR, ease: Tween.EaseType = Tween.EASE_IN_OUT) -> Tween:
	if fade_targets.is_empty() and scale_targets.is_empty():
		return null

	var tw: Tween = owner.create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	for entry in fade_targets:
		tw.tween_property(entry["node"], "modulate:a", 0.0, duration).set_trans(trans).set_ease(ease)

	for node in scale_targets:
		tw.tween_property(node, "scale", to_scale, duration).set_trans(trans).set_ease(ease)

	return tw


## menu-33: a framed menu panel comes in with a short scale rise + fade while its gold
## corners (MenuFrameDecor.reveal) draw themselves out. Real time.
static func play_panel_in(owner: Node, panel: Control, duration: float = 0.3) -> Tween:
	if panel == null:
		return null
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.97, 0.97)
	panel.modulate.a = 0.0
	var tw: Tween = owner.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(panel, "scale", Vector2.ONE, duration)
	tw.tween_property(panel, "modulate:a", 1.0, duration * 0.8)
	var decor := MenuFrameDecor.of(panel)
	if decor:
		decor.reveal = 0.0
		tw.tween_property(decor, "reveal", 1.0, duration * 1.6).set_delay(duration * 0.25)
	return tw


## menu-33: counterpart of play_panel_in (quick fade + slight shrink).
static func play_panel_out(owner: Node, panel: Control, duration: float = 0.18) -> Tween:
	if panel == null:
		return null
	panel.pivot_offset = panel.size * 0.5
	var tw: Tween = owner.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_ignore_time_scale(true)
	tw.tween_property(panel, "scale", Vector2(0.98, 0.98), duration)
	tw.tween_property(panel, "modulate:a", 0.0, duration)
	return tw


## menu-33: staggered entrance of a column of controls: each one fades in while it
## slides `slide` px into place, `stagger` s after the previous one. Call after the
## container has laid them out (positions are read as the final ones).
static func play_stagger_in(owner: Node, nodes: Array, slide: Vector2 = Vector2(-36, 0),
		stagger: float = 0.07, duration: float = 0.38, delay: float = 0.0) -> Tween:
	var tw: Tween = owner.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.set_ignore_time_scale(true)
	var i := 0
	for node in nodes:
		var c := node as Control
		if c == null or not is_instance_valid(c):
			continue
		var final_pos := c.position
		c.position = final_pos + slide
		c.modulate.a = 0.0
		var d := delay + stagger * i
		tw.tween_property(c, "position", final_pos, duration).set_delay(d)
		tw.tween_property(c, "modulate:a", 1.0, duration * 0.8).set_delay(d)
		i += 1
	if i == 0:
		tw.kill()
		return null
	return tw
