extends Control
class_name StatIcon

@export_enum("hp", "industry", "food", "science", "dust", "potion")
var icon_type: String = "hp":
	set(value):
		if icon_type == value:
			return
		icon_type = value
		queue_redraw()

const BASE_COLORS := {
	"hp": QuestPalette.BLOOD,
	"industry": QuestPalette.STEEL,
	"food": QuestPalette.BLOOD_LIGHT,
	"science": QuestPalette.VIOLET,
	"dust": QuestPalette.PARCHMENT_LIGHT,
	"potion": QuestPalette.GOLD
}

const OUTLINE_COLOR = Color(0.05, 0.03, 0.02, 0.9)
const SHADOW_COLOR = Color(0.08, 0.07, 0.06, 0.22)

@export_range(0.0, 8.0, 0.5)
var outline_size: float = 2.0:
	set(value):
		outline_size = value
		queue_redraw()

@export var enable_shadow: bool = true:
	set(value):
		enable_shadow = value
		queue_redraw()

@export var shadow_offset: Vector2 = Vector2(2, 2):
	set(value):
		shadow_offset = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(24, 24)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var draw_size: Vector2 = size.max(Vector2.ONE)
	var color: Color = BASE_COLORS.get(icon_type, QuestPalette.PARCHMENT_LIGHT)

	if enable_shadow:
		_draw_icon(draw_size, SHADOW_COLOR, shadow_offset)

	_draw_icon(draw_size, OUTLINE_COLOR, Vector2.ZERO, outline_size)
	_draw_icon(draw_size, color)

func _draw_icon(
	draw_size: Vector2,
	color: Color,
	offset: Vector2 = Vector2.ZERO,
	expand: float = 0.0
) -> void:
	match icon_type:
		"hp":
			_draw_heart(draw_size, color, offset, expand)

		"industry":
			_draw_gear(draw_size, color, offset, expand)

		"food":
			_draw_wheat(draw_size, color, offset, expand)

		"science":
			_draw_flask(draw_size, color, offset, expand)

		"dust":
			_draw_sparkle(draw_size, color, offset, expand)

		"potion":
			_draw_potion(draw_size, color, offset, expand)

func _draw_heart(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y

	var radius: float = min(w, h) * (0.2 + expand * 0.01)

	var left := Vector2(w * 0.35, h * 0.33) + offset
	var right := Vector2(w * 0.65, h * 0.33) + offset
	var bottom := Vector2(w * 0.5, h * 0.88 + expand) + offset

	var tri_points := PackedVector2Array([
		Vector2(w * 0.12 - expand, h * 0.42) + offset,
		Vector2(w * 0.88 + expand, h * 0.42) + offset,
		bottom
	])

	draw_circle(left, radius, color)
	draw_circle(right, radius, color)
	draw_polygon(tri_points, PackedColorArray([color]))

func _draw_gear(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var center: Vector2 = draw_size * 0.5 + offset
	var outer_radius: float = min(draw_size.x, draw_size.y) * (0.42 + expand * 0.01)
	var inner_radius: float = outer_radius * 0.55
	var teeth := 8

	var points := PackedVector2Array()
	for i in range(teeth * 2):
		var angle := (float(i) / float(teeth * 2)) * TAU
		var radius := outer_radius if i % 2 == 0 else inner_radius * 1.15
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)

	draw_polygon(points, PackedColorArray([color]))
	draw_circle(center, inner_radius * 0.55, color.darkened(0.4))

func _draw_wheat(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y

	var stem := Rect2(
		Vector2(w * 0.46 - expand * 0.5, h * 0.4) + offset,
		Vector2(w * 0.08 + expand, h * 0.5)
	)
	draw_rect(stem, color.darkened(0.3), true)

	for i in range(3):
		var y := h * (0.2 + i * 0.16)
		var left := Vector2(w * 0.5, y) + offset
		var tip_l := Vector2(w * 0.28 - expand, y - h * 0.08) + offset
		var tip_r := Vector2(w * 0.72 + expand, y - h * 0.08) + offset
		draw_polygon(PackedVector2Array([left, tip_l, left + Vector2(0, h * 0.06)]), PackedColorArray([color]))
		draw_polygon(PackedVector2Array([left, tip_r, left + Vector2(0, h * 0.06)]), PackedColorArray([color]))

func _draw_flask(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y

	var neck := Rect2(
		Vector2(w * 0.42, h * 0.1) + offset,
		Vector2(w * 0.16, h * 0.22)
	)
	draw_rect(neck, color.darkened(0.2), true)

	var body := PackedVector2Array([
		Vector2(w * 0.42, h * 0.32) + offset,
		Vector2(w * 0.58, h * 0.32) + offset,
		Vector2(w * 0.78 + expand, h * 0.86 + expand) + offset,
		Vector2(w * 0.22 - expand, h * 0.86 + expand) + offset
	])
	draw_polygon(body, PackedColorArray([color]))

	var bubble_color := QuestPalette.with_alpha(QuestPalette.UI_TEXT_PRIMARY, 0.35)
	draw_circle(Vector2(w * 0.4, h * 0.68) + offset, w * 0.05, bubble_color)
	draw_circle(Vector2(w * 0.58, h * 0.76) + offset, w * 0.04, bubble_color)

func _draw_sparkle(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var center: Vector2 = draw_size * 0.5 + offset
	var radius: float = min(draw_size.x, draw_size.y) * (0.42 + expand * 0.01)

	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.28, -radius * 0.28),
		center + Vector2(radius, 0),
		center + Vector2(radius * 0.28, radius * 0.28),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.28, radius * 0.28),
		center + Vector2(-radius, 0),
		center + Vector2(-radius * 0.28, -radius * 0.28),
	])

	draw_polygon(points, PackedColorArray([color]))

func _draw_potion(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y

	var bottle_points := PackedVector2Array([
		Vector2(w * 0.36, h * 0.18) + offset,
		Vector2(w * 0.64, h * 0.18) + offset,
		Vector2(w * 0.72 + expand, h * 0.38) + offset,
		Vector2(w * 0.68 + expand, h * 0.82 + expand) + offset,
		Vector2(w * 0.32 - expand, h * 0.82 + expand) + offset,
		Vector2(w * 0.28 - expand, h * 0.38) + offset
	])

	draw_polygon(bottle_points, PackedColorArray([color]))

	var liquid := Rect2(
		Vector2(w * 0.34, h * 0.54) + offset,
		Vector2(w * 0.32, h * 0.2 + expand)
	)

	draw_rect(liquid, color.lightened(0.25), true)

	var cork := Rect2(
		Vector2(w * 0.42, h * 0.08 - expand * 0.5) + offset,
		Vector2(w * 0.16, h * 0.12 + expand)
	)

	draw_rect(cork, color.darkened(0.5), true)