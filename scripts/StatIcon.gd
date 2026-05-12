extends Control
class_name StatIcon

@export_enum("hp", "strength", "magic", "dexterity", "potion")
var icon_type: String = "hp":
	set(value):
		if icon_type == value:
			return
		icon_type = value
		queue_redraw()

const BASE_COLORS := {
	"hp": Color(0.92, 0.22, 0.25),
	"strength": Color(0.82, 0.84, 0.9),
	"magic": Color(0.45, 0.65, 1.0),
	"dexterity": Color(0.92, 0.92, 0.92),
	"potion": Color(0.82, 0.3, 0.6)
}

const OUTLINE_COLOR := Color(0.08, 0.08, 0.08, 0.9)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.22)

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
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(24, 24)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var draw_size: Vector2 = size.max(Vector2.ONE)
	var color: Color = BASE_COLORS.get(icon_type, Color.WHITE)

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

		"strength":
			_draw_sword(draw_size, color, offset, expand)

		"magic":
			_draw_orb(draw_size, color, offset, expand)

		"dexterity":
			_draw_boot(draw_size, color, offset, expand)

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

func _draw_sword(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y

	var blade := Rect2(
		Vector2(w * 0.42 - expand * 0.5, h * 0.16) + offset,
		Vector2(w * 0.16 + expand, h * 0.5)
	)

	draw_rect(blade, color, true)

	var tip := PackedVector2Array([
		Vector2(w * 0.5, h * 0.04 - expand) + offset,
		Vector2(w * 0.38 - expand, h * 0.18) + offset,
		Vector2(w * 0.62 + expand, h * 0.18) + offset
	])

	draw_polygon(tip, PackedColorArray([color]))

	var guard := Rect2(
		Vector2(w * 0.26 - expand, h * 0.64) + offset,
		Vector2(w * 0.48 + expand * 2.0, h * 0.08 + expand)
	)

	var grip := Rect2(
		Vector2(w * 0.44 - expand * 0.5, h * 0.72) + offset,
		Vector2(w * 0.12 + expand, h * 0.18)
	)

	draw_rect(guard, color, true)
	draw_rect(grip, color.darkened(0.35), true)

func _draw_orb(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var center: Vector2 = draw_size * 0.5 + offset
	var radius: float = min(draw_size.x, draw_size.y) * (0.32 + expand * 0.01)

	draw_circle(center, radius, color)

	draw_circle(
		center - Vector2(radius * 0.22, radius * 0.22),
		radius * 0.45,
		Color(1, 1, 1, 0.22)
	)

	draw_arc(
		center,
		radius * 0.78,
		deg_to_rad(210),
		deg_to_rad(330),
		20,
		Color(1, 1, 1, 0.35),
		max(1.0, outline_size * 0.5),
		true
	)

func _draw_boot(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y

	var boot_points := PackedVector2Array([
		Vector2(w * 0.4, h * 0.12 - expand) + offset,
		Vector2(w * 0.62 + expand, h * 0.12 - expand) + offset,
		Vector2(w * 0.62 + expand, h * 0.56) + offset,
		Vector2(w * 0.82 + expand, h * 0.68) + offset,
		Vector2(w * 0.78 + expand, h * 0.84 + expand) + offset,
		Vector2(w * 0.18 - expand, h * 0.84 + expand) + offset,
		Vector2(w * 0.22 - expand, h * 0.62) + offset,
		Vector2(w * 0.4, h * 0.62) + offset
	])

	draw_polygon(boot_points, PackedColorArray([color]))

	var sole := PackedVector2Array([
		Vector2(w * 0.16, h * 0.82) + offset,
		Vector2(w * 0.8, h * 0.82) + offset,
		Vector2(w * 0.76, h * 0.9 + expand) + offset,
		Vector2(w * 0.2, h * 0.9 + expand) + offset
	])

	draw_polygon(sole, PackedColorArray([color.darkened(0.45)]))

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