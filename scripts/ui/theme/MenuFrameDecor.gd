class_name MenuFrameDecor
extends Control

## menu-33: ornaments of a framed menu panel (UiStyles.style_menu_frame): an inner gold
## hairline, L-shaped gold brackets with a lozenge on each corner and a notch at the top
## centre. `reveal` (0..1) draws them out; MenuTransitionFX.play_panel_in tweens it.
## Internal child of the panel, ignores the mouse.

const NODE_NAME := "MenuFrameDecor"

var reveal: float = 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()


static func attach(panel: Control) -> MenuFrameDecor:
	var existing := of(panel)
	if existing:
		return existing
	var decor := MenuFrameDecor.new()
	decor.name = NODE_NAME
	panel.add_child(decor, false, Node.INTERNAL_MODE_BACK)
	return decor


static func of(panel: Node) -> MenuFrameDecor:
	if panel == null:
		return null
	for child in panel.get_children(true):
		if child is MenuFrameDecor:
			return child
	return null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	item_rect_changed.connect(queue_redraw)
	var host := get_parent() as Control
	if host:
		host.resized.connect(queue_redraw)


## A PanelContainer lays this child out inside its content margins: draw on the
## panel's own rect instead (offset by our position).
func _draw() -> void:
	var host := get_parent() as Control
	var origin := -position if host else Vector2.ZERO
	var full: Vector2 = host.size if host else size
	if full.x < 40.0 or full.y < 40.0 or reveal <= 0.0:
		return
	draw_set_transform(origin)
	var inner := Rect2(Vector2.ZERO, full).grow(-7.0)
	draw_rect(inner, Color(QuestPalette.AGED_GOLD, 0.3 * reveal), false, 1.0)
	var gold := Color(QuestPalette.RELIC_GOLD, reveal)
	var arm := minf(46.0, minf(full.x, full.y) * 0.18) * ease(reveal, 0.5)
	var corners := [
		[Vector2(0, 0), Vector2(1, 1)], [Vector2(full.x, 0), Vector2(-1, 1)],
		[Vector2(0, full.y), Vector2(1, -1)], [Vector2(full.x, full.y), Vector2(-1, -1)]]
	for c: Array in corners:
		var p: Vector2 = c[0] + c[1] * 2.0
		var d: Vector2 = c[1]
		draw_line(p, p + Vector2(d.x * arm, 0), gold, 3.0)
		draw_line(p, p + Vector2(0, d.y * arm), gold, 3.0)
		_lozenge(c[0] + d * 9.0, 4.0, Color(QuestPalette.RELIC_GOLD_PALE, reveal))
	var top := Vector2(full.x * 0.5, 1.0)
	var wing := 34.0 * ease(reveal, 0.5)
	draw_line(top + Vector2(-wing - 8.0, 0), top + Vector2(-8.0, 0), gold, 2.0)
	draw_line(top + Vector2(8.0, 0), top + Vector2(wing + 8.0, 0), gold, 2.0)
	_lozenge(top, 6.0, Color(QuestPalette.RELIC_GOLD_PALE, reveal))


func _lozenge(center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.75, 0), center + Vector2(0, r), center + Vector2(-r * 0.75, 0)])
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, Color(QuestPalette.INK, 0.8 * reveal), 1.0, true)
