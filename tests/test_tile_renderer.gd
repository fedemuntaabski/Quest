extends SceneTree

## Headless self-check for MapTileRenderer over 25 seed x floor maps + the
## fallback layout: (a) same layout -> identical plan; (b) every walkable tile
## has floor and no wall, decor stays on room floor; (c) floor tiles connect
## every room to the start; (d) live layers: nothing drawn until show_zone, then
## only that zone, walls carry physics and floors don't. Run:
##   godot --headless --path . --script res://tests/test_tile_renderer.gd

const SEEDS := 5
const FLOORS := 5
const T := ArtConfig.CELL_TILES

var failures: Array[String] = []


func _initialize() -> void:
	var floor_config := load("res://resources/floors/default_floor_config.tres") as FloorConfig
	var visual := load("res://resources/maps/map_visual_config.tres") as MapVisualConfig
	var layouts: Array[MapLayout] = [load("res://resources/maps/fallback_layout.tres") as MapLayout]
	for floor_index in range(1, FLOORS + 1):
		for s in SEEDS:
			layouts.append(MapGenerator.generate_floor(s * 7919 + floor_index, floor_config, floor_index))

	for layout in layouts:
		var where := "seed %d" % layout.map_seed
		var plan := MapTileRenderer.build_plan(layout, visual)
		_check_deterministic(layout, visual, plan, where)
		_check_walkable(layout, plan, where)
		_check_connected(layout, plan, where)
	if MapTileRenderer.build_plan(layouts[1], visual) == MapTileRenderer.build_plan(layouts[2], visual):
		failures.append("different seeds produced identical plans")

	await _check_live(layouts[1], visual)

	for failure in failures.slice(0, 20):
		printerr("FAIL: ", failure)
	print("test_tile_renderer: %s (%d failures, %d layouts)" % ["OK" if failures.is_empty() else "FAILED", failures.size(), layouts.size()])
	quit(0 if failures.is_empty() else 1)


func _check_deterministic(layout: MapLayout, visual: MapVisualConfig, plan: Dictionary, where: String) -> void:
	var again := MapTileRenderer.build_plan(layout, visual)
	if again.hash() != plan.hash() or again != plan:
		failures.append("%s: same layout produced different tile plans" % where)


## Tiles of a zone rect (cells x T) -> zone id.
func _walkable_tiles(layout: MapLayout) -> Dictionary:
	var tiles: Dictionary = {}
	var rects: Array = []
	for room in layout.rooms:
		rects.append([room.id, room.get_rect()])
	for corridor in layout.corridors:
		rects.append([corridor.id, corridor.get_zone_rect()])
	for entry in rects:
		var rect: Rect2i = entry[1]
		for x in range(rect.position.x * T, rect.end.x * T):
			for y in range(rect.position.y * T, rect.end.y * T):
				tiles[Vector2i(x, y)] = entry[0]
	return tiles


func _check_walkable(layout: MapLayout, plan: Dictionary, where: String) -> void:
	var walkable := _walkable_tiles(layout)
	var floors: Dictionary = {}
	var walls: Dictionary = {}
	var room_ids: Dictionary = {}
	for room in layout.rooms:
		room_ids[room.id] = true
	for id in plan["zones"]:
		floors.merge(plan["zones"][id]["floor"])
		walls.merge(plan["zones"][id]["walls"])
		for tile in plan["zones"][id]["decor"]:
			if not room_ids.has(id) or not walkable.has(tile):
				failures.append("%s: decor at %s outside room floor (zone %s)" % [where, tile, id])
	for tile in walkable:
		if not floors.has(tile):
			failures.append("%s: walkable tile %s has no floor" % [where, tile])
		if walls.has(tile):
			failures.append("%s: walkable tile %s has a wall" % [where, tile])
	for tile in floors:
		if not walkable.has(tile):
			failures.append("%s: floor tile %s is not walkable" % [where, tile])
	# Stairs only inside the exit room.
	for room in layout.rooms:
		var has_stairs: bool = false
		for v in plan["zones"][room.id]["floor"].values():
			has_stairs = has_stairs or (Vector2i(v.y, v.z) == DungeonTiles.STAIRS)
		if has_stairs != room.is_exit:
			failures.append("%s: room %s stairs=%s but is_exit=%s" % [where, room.id, has_stairs, room.is_exit])


## 4-neighbour flood fill over floor tiles from the start room reaches every room and corridor.
func _check_connected(layout: MapLayout, plan: Dictionary, where: String) -> void:
	var floors: Dictionary = {}
	for id in plan["zones"]:
		floors.merge(plan["zones"][id]["floor"])
	var start := layout.get_room(layout.get_start_room_id())
	var origin := start.pos * T
	var seen: Dictionary = {origin: true}
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_back()
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = tile + d
			if floors.has(n) and not seen.has(n):
				seen[n] = true
				frontier.append(n)
	if seen.size() != floors.size():
		failures.append("%s: floor not connected (%d of %d tiles reachable)" % [where, seen.size(), floors.size()])


func _check_live(layout: MapLayout, visual: MapVisualConfig) -> void:
	var renderer := (load("res://scenes/world/MapTileRenderer.tscn") as PackedScene).instantiate() as MapTileRenderer
	root.add_child(renderer)
	await process_frame
	renderer.build(layout, visual)
	var layers: Array[TileMapLayer] = [renderer.floor_layer, renderer.walls_layer, renderer.decor_layer, renderer.doors_layer]
	for layer in layers:
		if not layer.get_used_cells().is_empty():
			failures.append("live: %s has tiles before any show_zone" % layer.name)
	if renderer.scale != Vector2.ONE * ArtConfig.ART_SCALE:
		failures.append("live: renderer scale %s != ART_SCALE" % renderer.scale)

	var start_id := layout.get_start_room_id()
	renderer.show_zone(start_id)
	var zone: Dictionary = renderer.get_plan()["zones"][start_id]
	if renderer.floor_layer.get_used_cells().size() != zone["floor"].size():
		failures.append("live: floor tiles drawn != plan of the start room")
	if renderer.walls_layer.get_used_cells().size() != zone["walls"].size():
		failures.append("live: wall tiles drawn != plan of the start room")
	for tile in renderer.floor_layer.get_used_cells():
		if not zone["floor"].has(tile):
			failures.append("live: floor tile %s drawn outside the start room" % tile)
			break
		var data := renderer.floor_layer.get_cell_tile_data(tile)
		if renderer.walls_layer.get_cell_source_id(tile) != -1:
			failures.append("live: wall over walkable tile %s" % tile)
			break
		if data.get_collision_polygons_count(0) != 0:
			failures.append("live: floor tile %s has collision" % tile)
			break
	for tile in renderer.walls_layer.get_used_cells():
		if renderer.walls_layer.get_cell_tile_data(tile).get_collision_polygons_count(0) == 0:
			failures.append("live: wall tile %s has no collision polygon" % tile)
			break
	renderer.show_zone(start_id)  # idempotent
	if renderer.floor_layer.get_used_cells().size() != zone["floor"].size():
		failures.append("live: show_zone not idempotent")

	var corridor := layout.corridors[0]
	renderer.show_door(corridor.id, false, false)
	if not renderer.doors_layer.get_used_cells().is_empty():
		failures.append("live: door drawn while its origin room is hidden")
	renderer.show_door(corridor.id, true, false)
	if renderer.doors_layer.get_used_cells().size() != 1:
		failures.append("live: closed door not drawn")
	renderer.queue_free()
