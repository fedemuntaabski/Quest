extends Control
class_name StatIcon

@export var icon_type: String = "hp"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	var color: Color = _get_color()

	match icon_type:
		"hp":
			_draw_heart(w, h, color)
		"strength":
			_draw_sword(w, h, color)
		"magic":
			_draw_orb(w, h, color)
		"dexterity":
			_draw_boot(w, h, color)
		"potion":
			_draw_potion(w, h, color)
		_:
			draw_rect(Rect2(Vector2.ZERO, size), color, true)

func _get_color() -> Color:
	match icon_type:
		"hp":
			return Color(0.9, 0.2, 0.2, 1.0)
		"strength":
			return Color(0.85, 0.85, 0.85, 1.0)
		"magic":
			return Color(0.45, 0.6, 1.0, 1.0)
		"dexterity":
			return Color(0.9, 0.9, 0.9, 1.0)
		"potion":
			return Color(0.85, 0.3, 0.55, 1.0)
		_:
			return Color(0.8, 0.8, 0.8, 1.0)

func _draw_heart(w: float, h: float, color: Color) -> void:
	var r: float = min(w, h) * 0.22
	var left: Vector2 = Vector2(w * 0.35, h * 0.35)
	var right: Vector2 = Vector2(w * 0.65, h * 0.35)
	var bottom: Vector2 = Vector2(w * 0.5, h * 0.85)
	var tri_left: Vector2 = Vector2(w * 0.15, h * 0.45)
	var tri_right: Vector2 = Vector2(w * 0.85, h * 0.45)
	var tri_points: PackedVector2Array = PackedVector2Array([tri_left, tri_right, bottom])
	var tri_colors: PackedColorArray = PackedColorArray([color])

	draw_circle(left, r, color)
	draw_circle(right, r, color)
	draw_polygon(tri_points, tri_colors)

func _draw_sword(w: float, h: float, color: Color) -> void:
	var blade_width: float = w * 0.2
	var blade_height: float = h * 0.55
	var blade_pos: Vector2 = Vector2((w - blade_width) * 0.5, h * 0.12)
	draw_rect(Rect2(blade_pos, Vector2(blade_width, blade_height)), color, true)

	var tip: Vector2 = Vector2(w * 0.5, h * 0.05)
	var tip_left: Vector2 = Vector2(w * 0.4, h * 0.18)
	var tip_right: Vector2 = Vector2(w * 0.6, h * 0.18)
	var tip_points: PackedVector2Array = PackedVector2Array([tip, tip_left, tip_right])
	var tip_colors: PackedColorArray = PackedColorArray([color])
	draw_polygon(tip_points, tip_colors)

	var handle_width: float = w * 0.36
	var handle_height: float = h * 0.12
	var handle_pos: Vector2 = Vector2((w - handle_width) * 0.5, h * 0.7)
	var handle_color: Color = Color(0.55, 0.4, 0.25, 1.0)
	draw_rect(Rect2(handle_pos, Vector2(handle_width, handle_height)), handle_color, true)

func _draw_orb(w: float, h: float, color: Color) -> void:
	var radius: float = min(w, h) * 0.32
	var center: Vector2 = Vector2(w * 0.5, h * 0.5)
	var inner_color: Color = Color(color.r, color.g, color.b, 0.45)
	draw_circle(center, radius, color)
	draw_circle(center, radius * 0.6, inner_color)

func _draw_boot(w: float, h: float, color: Color) -> void:
	var ankle := Rect2(w * 0.38, h * 0.12, w * 0.24, h * 0.5)
	var foot := Rect2(w * 0.22, h * 0.58, w * 0.56, h * 0.22)
	var sole := Rect2(w * 0.2, h * 0.78, w * 0.6, h * 0.08)
	draw_rect(ankle, color, true)
	draw_rect(foot, color, true)
	draw_rect(sole, Color(0.2, 0.2, 0.2, 1.0), true)

func _draw_potion(w: float, h: float, color: Color) -> void:
	var bottle := Rect2(w * 0.28, h * 0.28, w * 0.44, h * 0.54)
	var neck := Rect2(w * 0.42, h * 0.14, w * 0.16, h * 0.16)
	var cap := Rect2(w * 0.38, h * 0.06, w * 0.24, h * 0.08)
	draw_rect(bottle, color, true)
	draw_rect(neck, color, true)
	draw_rect(cap, Color(0.2, 0.2, 0.2, 1.0), true)
