extends Control
class_name StatIcon

@export_enum("hp", "iron", "food", "lore", "embers", "lock")
var icon_type: String = "hp":
	set(value):
		if icon_type == value:
			return
		icon_type = value
		queue_redraw()

const BASE_COLORS := {
	"hp": QuestPalette.BLOOD,
	"iron": QuestPalette.STEEL,
	"food": QuestPalette.BLOOD_LIGHT,
	"lore": QuestPalette.VIOLET,
	"embers": Color(0.96, 0.55, 0.2),
	"lock": QuestPalette.GOLD_DARK
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

## Unit-square outline of the Brasas flame.
const FLAME: Array[Vector2] = [Vector2(0.54, 0.04), Vector2(0.66, 0.26), Vector2(0.84, 0.48), Vector2(0.88, 0.68),
	Vector2(0.72, 0.88), Vector2(0.5, 0.96), Vector2(0.28, 0.88), Vector2(0.12, 0.68), Vector2(0.2, 0.46), Vector2(0.3, 0.54), Vector2(0.36, 0.3)]


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

		"iron":
			_draw_anvil(draw_size, color, offset, expand)

		"food":
			_draw_wheat(draw_size, color, offset, expand)

		"lore":
			_draw_book(draw_size, color, offset, expand)

		"embers":
			_draw_flame(draw_size, color, offset, expand)

		"lock":
			_draw_lock(draw_size, color, offset, expand)

## Padlock (BuildingMenu: building locked behind research).
func _draw_lock(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y
	draw_arc(Vector2(w * 0.5, h * 0.42) + offset, w * 0.2, PI, TAU, 12, color, w * 0.1 + expand)
	draw_rect(Rect2(Vector2(w * 0.2 - expand, h * 0.42 - expand) + offset, Vector2(w * 0.6 + expand * 2.0, h * 0.46 + expand * 2.0)), color, true)

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

func _draw_anvil(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y
	# Face with its horn to the left, waist, foot.
	draw_polygon(PackedVector2Array([
		Vector2(w * 0.04 - expand, h * 0.3) + offset,
		Vector2(w * 0.96 + expand, h * 0.3 - expand) + offset,
		Vector2(w * 0.96 + expand, h * 0.52 + expand) + offset,
		Vector2(w * 0.34, h * 0.52 + expand) + offset,
	]), PackedColorArray([color]))
	draw_rect(Rect2(Vector2(w * 0.42 - expand, h * 0.5) + offset, Vector2(w * 0.3 + expand * 2.0, h * 0.24)), color.darkened(0.15), true)
	draw_rect(Rect2(Vector2(w * 0.26 - expand, h * 0.72) + offset, Vector2(w * 0.62 + expand * 2.0, h * 0.14 + expand)), color, true)

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

func _draw_book(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y
	var spine_top := Vector2(w * 0.5, h * 0.3) + offset
	var spine_bottom := Vector2(w * 0.5, h * 0.88 + expand) + offset
	draw_polygon(PackedVector2Array([spine_top, Vector2(w * 0.06 - expand, h * 0.16 - expand) + offset,
		Vector2(w * 0.06 - expand, h * 0.74 + expand) + offset, spine_bottom]), PackedColorArray([color]))
	draw_polygon(PackedVector2Array([spine_top, spine_bottom, Vector2(w * 0.94 + expand, h * 0.74 + expand) + offset,
		Vector2(w * 0.94 + expand, h * 0.16 - expand) + offset]), PackedColorArray([color.darkened(0.2)]))

func _draw_flame(draw_size: Vector2, color: Color, offset: Vector2, expand: float) -> void:
	var w: float = draw_size.x
	var h: float = draw_size.y
	var outline := PackedVector2Array()
	for point: Vector2 in FLAME:
		outline.append(Vector2(w * point.x, h * point.y) + (point - Vector2(0.5, 0.6)) * expand * 2.0 + offset)
	draw_polygon(outline, PackedColorArray([color]))
	draw_circle(Vector2(w * 0.5, h * 0.72) + offset, w * 0.13, color.lightened(0.45))
