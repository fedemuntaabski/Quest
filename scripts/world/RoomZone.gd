extends Area2D
class_name RoomZone

## RoomZone: one clickable room or corridor in the room-graph. Replaces the
## old per-cell BFS Highlight overlay — hover/selection feedback is drawn
## directly on this zone's Fill/Outline instead of painting tiles.

signal clicked(zone: RoomZone)
signal hovered(zone: RoomZone)
signal unhovered(zone: RoomZone)

enum Highlight { NONE, CURRENT, REACHABLE, OPENABLE, BLOCKED }

const SHAPE_INSET := 6.0
const OUTLINE_WIDTH := 3.0
const REVEALED_IDLE_OUTLINE := Color(1, 1, 1, 0.25)

const FILL_COLORS := {
	Highlight.NONE: Color(1, 1, 1, 0.0),
	Highlight.CURRENT: Color(1, 1, 1, 0.06),
	Highlight.REACHABLE: Color(0.45, 0.85, 1.0, 0.20),
	Highlight.OPENABLE: Color(1.0, 0.75, 0.25, 0.22),
	Highlight.BLOCKED: Color(0.9, 0.25, 0.25, 0.16),
}
const OUTLINE_COLORS := {
	Highlight.NONE: Color(1, 1, 1, 0.0),
	Highlight.CURRENT: Color(1, 1, 1, 0.8),
	Highlight.REACHABLE: Color(0.45, 0.85, 1.0, 0.8),
	Highlight.OPENABLE: Color(1.0, 0.75, 0.25, 0.85),
	Highlight.BLOCKED: Color(0.9, 0.25, 0.25, 0.85),
}

@onready var fill: Polygon2D = $Fill
@onready var outline: Line2D = $Outline
@onready var collision: CollisionShape2D = $CollisionShape2D

var zone_id: String = ""
var kind: String = ""

var _state: int = Highlight.NONE
var _revealed: bool = false


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(func(): hovered.emit(self))
	mouse_exited.connect(func(): unhovered.emit(self))


## `size_px` is the zone's full world-space size (rect.size * tile_size).
func configure(p_zone_id: String, size_px: Vector2, p_kind: String) -> void:
	zone_id = p_zone_id
	kind = p_kind

	var half := (size_px - Vector2.ONE * SHAPE_INSET * 2.0) / 2.0
	var points := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])

	fill.polygon = points
	outline.points = PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	outline.width = OUTLINE_WIDTH

	var shape := RectangleShape2D.new()
	shape.size = size_px - Vector2.ONE * SHAPE_INSET * 2.0
	collision.shape = shape

	set_highlight(Highlight.NONE)


func set_revealed(v: bool) -> void:
	_revealed = v
	_apply_visual()


func is_revealed() -> bool:
	return _revealed


func set_highlight(state: int) -> void:
	_state = state
	_apply_visual()


func _apply_visual() -> void:
	fill.color = FILL_COLORS.get(_state, FILL_COLORS[Highlight.NONE])
	outline.default_color = REVEALED_IDLE_OUTLINE if (_state == Highlight.NONE and _revealed) \
		else OUTLINE_COLORS.get(_state, OUTLINE_COLORS[Highlight.NONE])


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	clicked.emit(self)
	get_viewport().set_input_as_handled()
