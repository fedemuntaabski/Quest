extends RefCounted
class_name DungeonRoomObstaclePlacer

const MIN_RECT_SIZE := Vector2i(9, 7)
const OBSTACLE_CELL_RATIO := 0.12
const SKIP_TEMPLATES := ["tutorial"]


static func place_obstacles(dungeon: DungeonGenerator) -> void:
	for room_info in dungeon.room_infos:
		_place_obstacles_in_room(dungeon, room_info)


static func _place_obstacles_in_room(dungeon: DungeonGenerator, room_info: Dictionary) -> void:
	var room_id: int = room_info.get("id", -1)
	var rect: Rect2i = room_info.get("rect", Rect2i())
	var template: String = room_info.get("template", "")
	if SKIP_TEMPLATES.has(template):
		return
	if rect.size.x < MIN_RECT_SIZE.x or rect.size.y < MIN_RECT_SIZE.y:
		return

	var room_floor_cells: Array = room_info.get("floor_cells", [])
	if room_floor_cells.is_empty():
		return

	var forbidden: Dictionary = dungeon.get_room_spawn_forbidden_cells(room_id)
	var max_obstacles := maxi(1, int(room_floor_cells.size() * OBSTACLE_CELL_RATIO))

	var candidates := _roll_pattern_cells(rect, dungeon.rng)
	var floor_set: Dictionary = {}
	for cell in room_floor_cells:
		floor_set[cell] = true

	var chosen: Array[Vector2i] = []
	for cell in candidates:
		if chosen.size() >= max_obstacles:
			break
		if forbidden.has(cell):
			continue
		if not floor_set.has(cell):
			continue
		chosen.append(cell)

	if chosen.is_empty():
		return

	if not _keeps_entrances_connected(floor_set, chosen, forbidden):
		QuestLogger.warn(QuestLogger.Category.MAP, "DungeonRoomObstaclePlacer: skipped obstacles in room %d (would block entrance connectivity)" % room_id)
		return

	for cell in chosen:
		dungeon.floor_cells.erase(cell)
		room_floor_cells.erase(cell)


static func _roll_pattern_cells(rect: Rect2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var roll := rng.randf()
	if roll < 0.5:
		return _pillars(rect, rng)
	elif roll < 0.8:
		return _center_cover(rect, rng)
	return _corner_baffles(rect, rng)


static func _pillars(rect: Rect2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var pillar_count := rng.randi_range(1, 3)
	for i in range(pillar_count):
		var x := rng.randi_range(rect.position.x + 2, rect.end.x - 3)
		var y := rng.randi_range(rect.position.y + 2, rect.end.y - 3)
		cells.append(Vector2i(x, y))
	return cells


static func _center_cover(rect: Rect2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var center := rect.position + rect.size / 2
	var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
	var base := center + offset
	return [base, base + Vector2i(1, 0)]


static func _corner_baffles(rect: Rect2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var inset := 2
	var corners := [
		rect.position + Vector2i(inset, inset),
		Vector2i(rect.end.x - 1 - inset, rect.position.y + inset),
		Vector2i(rect.position.x + inset, rect.end.y - 1 - inset),
		Vector2i(rect.end.x - 1 - inset, rect.end.y - 1 - inset)
	]
	corners.shuffle()
	for i in range(mini(2, corners.size())):
		var c: Vector2i = corners[i]
		cells.append(c)
		cells.append(c + Vector2i(1, 0))
	return cells


static func _keeps_entrances_connected(floor_set: Dictionary, obstacle_cells: Array[Vector2i], forbidden: Dictionary) -> bool:
	var entrance_cells: Array[Vector2i] = []
	for cell_variant in forbidden.keys():
		var cell: Vector2i = cell_variant
		if floor_set.has(cell):
			entrance_cells.append(cell)

	if entrance_cells.size() <= 1:
		return true

	var blocked: Dictionary = {}
	for cell in obstacle_cells:
		blocked[cell] = true

	var reachable: Dictionary = {}
	var pending: Array[Vector2i] = [entrance_cells[0]]
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back()
		if reachable.has(current) or blocked.has(current) or not floor_set.has(current):
			continue
		reachable[current] = true
		var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
		for dir in dirs:
			var neighbor: Vector2i = current + dir
			if not reachable.has(neighbor):
				pending.append(neighbor)

	for cell in entrance_cells:
		if not reachable.has(cell):
			return false
	return true
