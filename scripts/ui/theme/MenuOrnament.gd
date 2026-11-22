class_name MenuOrnament
extends Control

## menu-33: gold rule under a menu title: fades out to both ends, a lozenge and two
## dots in the middle. `align_left` starts it at the left edge (main menu title).

var align_left: bool = false:
	set(value):
		align_left = value
		queue_redraw()
var color: Color = QuestPalette.RELIC_GOLD


func _init() -> void:
	custom_minimum_size = Vector2(120, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var cy := size.y * 0.5
	var cx := 9.0 if align_left else size.x * 0.5
	var reach := size.x - cx - 4.0 if align_left else size.x * 0.5 - 4.0
	var steps := 16
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var a := (1.0 - t0 * t0) * 0.9
		var x0 := 12.0 + (reach - 12.0) * t0
		var x1 := 12.0 + (reach - 12.0) * t1
		draw_line(Vector2(cx + x0, cy), Vector2(cx + x1, cy), Color(color, a), 2.0)
		if not align_left:
			draw_line(Vector2(cx - x0, cy), Vector2(cx - x1, cy), Color(color, a), 2.0)
	var r := 6.0
	var pts := PackedVector2Array([Vector2(cx, cy - r), Vector2(cx + r * 0.75, cy), Vector2(cx, cy + r), Vector2(cx - r * 0.75, cy)])
	draw_colored_polygon(pts, QuestPalette.RELIC_GOLD_PALE)
	draw_circle(Vector2(cx + 16.0, cy), 1.8, color)
	if not align_left:
		draw_circle(Vector2(cx - 16.0, cy), 1.8, color)
