extends Resource
class_name RoomData

## RoomData: one room of a MapLayout (cell space, tile = 64px). Its id is also
## its DoorTurnSystem reveal group id. Corridors are separate CorridorData.

## START/EXIT are never stored: get_room_type() derives them from is_start/
## is_exit. The rest come from MapGenerator.assign_room_types (FloorConfig
## RoomTypeRules); COMBAT is the plain default. Names, icons, colors and banners live in
## resources/maps/room_type_visual_config.tres, not here.
## progresion-10: ALTAR (8) and SECRET (9, MapGenerator.add_secret_room, never rolled).
enum RoomType { COMBAT, START, EXIT, REST, LOOT, ELITE, WORKSHOP, PRISONER, ALTAR, SECRET }

@export var id: String = ""
@export var room_type: RoomType = RoomType.COMBAT
@export var pos: Vector2i = Vector2i.ZERO
@export var size: Vector2i = Vector2i(5, 5)
## Room ids joined to this one by a corridor (both directions, loops included).
@export var neighbors: PackedStringArray = PackedStringArray()
@export var is_start: bool = false
@export var is_exit: bool = false
## mazmorra-31: square cut-outs at the corners, in cells (x = top-left, y = top-right,
## z = bottom-right, w = bottom-left; MapGenerator.assign_shapes). get_rect() stays the
## bounding box; the centre row and column are never cut (corridor lanes, centre objects).
@export var corner_cuts: Vector4i = Vector4i.ZERO


func get_rect() -> Rect2i:
	return Rect2i(pos, size)


func has_cell(cell: Vector2i) -> bool:
	return get_rect().has_point(cell) and not in_cut(cell - pos, size, corner_cuts)


func get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(pos.x, pos.x + size.x):
		for y in range(pos.y, pos.y + size.y):
			if not in_cut(Vector2i(x, y) - pos, size, corner_cuts):
				cells.append(Vector2i(x, y))
	return cells


## A cell (relative to the rect's top-left) inside one of the corner cut-outs.
static func in_cut(local: Vector2i, rect_size: Vector2i, cuts: Vector4i) -> bool:
	var far := rect_size - Vector2i.ONE - local
	return (local.x < cuts.x and local.y < cuts.x) or (far.x < cuts.y and local.y < cuts.y) \
		or (far.x < cuts.z and far.y < cuts.z) or (local.x < cuts.w and far.y < cuts.w)


## Outline of a rect of rect_size with corner cut-outs, clockwise from the top-left,
## relative to its top-left (same unit as rect_size and cuts).
static func outline(rect_size: Vector2, cuts: Vector4) -> PackedVector2Array:
	var w := rect_size.x
	var h := rect_size.y
	var points := PackedVector2Array()
	points.append_array([Vector2(0, cuts.x), Vector2(cuts.x, cuts.x), Vector2(cuts.x, 0)] if cuts.x > 0 else [Vector2.ZERO])
	points.append_array([Vector2(w - cuts.y, 0), Vector2(w - cuts.y, cuts.y), Vector2(w, cuts.y)] if cuts.y > 0 else [Vector2(w, 0)])
	points.append_array([Vector2(w, h - cuts.z), Vector2(w - cuts.z, h - cuts.z), Vector2(w - cuts.z, h)] if cuts.z > 0 else [Vector2(w, h)])
	points.append_array([Vector2(cuts.w, h), Vector2(cuts.w, h - cuts.w), Vector2(0, h - cuts.w)] if cuts.w > 0 else [Vector2(0, h)])
	return points


func get_room_type() -> RoomType:
	if is_start:
		return RoomType.START
	if is_exit:
		return RoomType.EXIT
	return room_type
