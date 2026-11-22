extends SceneTree

## Headless self-check for MapTileRenderer over 25 seed x floor maps + the
## fallback layout: (a) same layout -> identical plan; (b) every walkable tile
## has floor and no wall, decor stays on room floor; (c) floor tiles connect
## every room to the start; (d) live layers: nothing drawn until show_zone, then
## only that zone, walls carry physics and floors don't; (e) mazmorra-31 interior over
## 150 maps: solid pieces (columns, pits, rubble) stay off the outer ring, off every
## world object (build slots, Relic/chest, cage, altar) and off the walk line from each
## corridor to the room centre; every template shows up. Run:
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
	var seen := {"columns": 0, "pits": 0, "rugs": 0, "slabs": 0, "rubble": 0, "torches": 0, "braziers": 0, "candles": 0, "bedrolls": 0, "wall pieces": 0, "flat": 0}
	for floor_index in range(1, FLOORS + 1):
		for s in 30:
			var layout := MapGenerator.generate_floor(s * 104729 + floor_index, floor_config, floor_index)
			_check_interior(layout, MapTileRenderer.build_plan(layout, visual), "interior seed %d" % layout.map_seed, seen)
	for key in seen:
		if seen[key] == 0:
			failures.append("interior: no %s in 150 maps" % key)
	print("interior over 150 maps: ", seen)
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
		for cell in room.get_cells():  # mazmorra-31: cut corners are not floor
			rects.append([room.id, Rect2i(cell, Vector2i.ONE)])
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
		for key in ["decor", "features", "flat"]:
			for tile in plan["zones"][id][key]:
				if not room_ids.has(id) or walkable.get(tile, "") != id:
					failures.append("%s: %s at %s outside room floor (zone %s)" % [where, key, tile, id])
		# mazmorra-32: wall pieces only on this zone's own walls; lights only on a torch/brazier/candles.
		for tile in plan["zones"][id]["wall_decor"]:
			if not plan["zones"][id]["walls"].has(tile):
				failures.append("%s: wall piece at %s not on a wall of %s" % [where, tile, id])
		for light: Array in plan["zones"][id]["lights"]:
			var v: Vector4i = plan["zones"][id]["features"].get(light[0], plan["zones"][id]["wall_decor"].get(light[0], Vector4i(-1, 0, 0, 0)))
			if v.x != DungeonTiles.SRC_OWN or Vector2i(v.y, v.z) not in DungeonTiles.ANIMATED:
				failures.append("%s: light %s at %s has no flame tile (%s)" % [where, light[1], light[0], id])
		for tile in plan["zones"][id]["flat"]:
			if plan["zones"][id]["features"].has(tile):
				failures.append("%s: flat and solid piece share %s" % [where, tile])
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
	var layers: Array[TileMapLayer] = [renderer.floor_layer, renderer.walls_layer, renderer.features_layer, renderer.decor_layer]
	for layer in layers:
		if not layer.get_used_cells().is_empty():
			failures.append("live: %s has tiles before any show_zone" % layer.name)
	if renderer.scale != Vector2.ONE * ArtConfig.ART_SCALE:
		failures.append("live: renderer scale %s != ART_SCALE" % renderer.scale)

	var start_id := layout.get_start_room_id()
	renderer.show_zone(start_id)
	var zone: Dictionary = renderer.get_plan()["zones"][start_id]
	if renderer.floor_layer.get_used_cells().size() != zone["floor"].size() + zone["under"].size():
		failures.append("live: floor tiles drawn != plan of the start room (floor + under the caps)")
	if renderer.walls_layer.get_used_cells().size() != zone["walls"].size():
		failures.append("live: wall tiles drawn != plan of the start room")
	for tile in renderer.floor_layer.get_used_cells():
		if zone["under"].has(tile):  # fill behind a wall cap: must sit under a wall tile
			if renderer.walls_layer.get_cell_source_id(tile) == -1:
				failures.append("live: fill under %s with no wall cap over it" % tile)
				break
			continue
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
	if renderer.floor_layer.get_used_cells().size() != zone["floor"].size() + zone["under"].size():
		failures.append("live: show_zone not idempotent")

	# juego-21: every zone shown -> every planned tile exists in the baked tilesets
	# (no broken texture after moving the sheets out of _source/), every wall tile
	# is solid (banner faces had none), and some faces are worn bricks.
	var wear := 0
	for zone_id in renderer.get_plan()["zones"]:
		renderer.show_zone(zone_id)
		var z: Dictionary = renderer.get_plan()["zones"][zone_id]
		for key in ["floor", "walls", "decor", "under", "features"]:
			var layer: TileMapLayer = {"floor": renderer.floor_layer, "walls": renderer.walls_layer, "decor": renderer.decor_layer, "under": renderer.floor_layer, "features": renderer.features_layer}[key]
			for tile in z[key]:
				var v: Vector4i = z[key][tile]
				var src := layer.tile_set.get_source(v.x) as TileSetAtlasSource if layer.tile_set.has_source(v.x) else null
				if src == null or src.texture == null or not src.has_tile(Vector2i(v.y, v.z)) or not src.has_alternative_tile(Vector2i(v.y, v.z), v.w):
					failures.append("live: %s tile %s of %s not in the tileset (%s)" % [key, tile, zone_id, v])
				elif key == "walls" and Vector2i(v.y, v.z) in DungeonTiles.WALL_WEAR:
					wear += 1
	for tile in renderer.walls_layer.get_used_cells():
		if renderer.walls_layer.get_cell_tile_data(tile).get_collision_polygons_count(0) == 0:
			failures.append("live: wall tile %s (%s) has no collision polygon" % [tile, renderer.walls_layer.get_cell_atlas_coords(tile)])
			break
	if wear == 0:
		failures.append("live: no worn brick faces on the whole map")

	renderer.queue_free()



## World-object footprints relative to the room centre (px), checked against solid pieces.
func _object_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for offset: Vector2 in RoomZone.BUILDING_SLOT_OFFSETS:
		rects.append(Rect2(offset - Vector2(20, 20), Vector2(40, 40)))
	for i in 2:  # Workshop: two majors in a row
		rects.append(Rect2(Vector2((i - 0.5) * RoomZone.MAJOR_SLOT_SPACING, -14) - Vector2(20, 20), Vector2(40, 40)))
	rects.append(Rect2(LootSpawner.CHEST_OFFSET + Vector2(-20, -40), Vector2(40, 56)))  # chest, Relic (same offset)
	rects.append(Rect2(PrisonerSpawner.CAGE_OFFSET + Vector2(-PrisonerCage.SIZE.x / 2, -PrisonerCage.SIZE.y), PrisonerCage.SIZE))
	rects.append(Rect2(Vector2(0, -40) + Vector2(-AltarShrine.SIZE.x / 2, -AltarShrine.SIZE.y), AltarShrine.SIZE))
	return rects


func _check_interior(layout: MapLayout, plan: Dictionary, where: String, seen: Dictionary) -> void:
	var objects := _object_rects()
	for room in layout.rooms:
		var zone: Dictionary = plan["zones"][room.id]
		var rect := Rect2i(room.pos * T, room.size * T)
		var centre := (Vector2(room.pos) + Vector2(room.size) / 2.0) * 64.0
		var solid: Array[Vector2i] = []
		for tile in zone["features"]:
			solid.append(tile)
			var atlas := Vector2i(zone["features"][tile].y, zone["features"][tile].z)
			if atlas == DungeonTiles.COLUMN[2]:
				seen["columns"] += 1
			elif atlas in DungeonTiles.RUBBLE:
				seen["rubble"] += 1
			elif atlas == DungeonTiles.BRAZIER:
				seen["braziers"] += 1
			elif atlas == DungeonTiles.CANDLES:
				seen["candles"] += 1
			elif atlas == DungeonTiles.BEDROLL[0]:
				seen["bedrolls"] += 1
		for tile in zone["wall_decor"]:
			seen["torches" if Vector2i(zone["wall_decor"][tile].y, zone["wall_decor"][tile].z) == DungeonTiles.TORCH else "wall pieces"] += 1
		seen["flat"] += zone["flat"].size()
		for tile in zone["floor"]:
			var v: Vector4i = zone["floor"][tile]
			if v.x != DungeonTiles.SRC_OWN:
				continue
			var atlas := Vector2i(v.y, v.z)
			if atlas in DungeonTiles.PIT:
				solid.append(tile)
				seen["pits"] += int(atlas == DungeonTiles.PIT[0])
			elif atlas in DungeonTiles.RUG:
				seen["rugs"] += int(atlas == DungeonTiles.RUG[0])
			elif atlas in DungeonTiles.SLABS:
				seen["slabs"] += 1
		# Walk lines: corridor zone centre -> room centre, 20 px either side.
		var walks: Array = []
		for corridor in layout.corridors:
			if corridor.room_a == room.id or corridor.room_b == room.id:
				var zr := corridor.get_zone_rect()
				walks.append([(Vector2(zr.position) + Vector2(zr.size) / 2.0) * 64.0, centre])
		for tile in solid:
			var px := Rect2(Vector2(tile) * 32.0, Vector2(32, 32))
			var ring := false
			for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				ring = ring or not room.has_cell(Vector2i((Vector2(tile + d) / T).floor()))
			if ring or not room.has_cell(Vector2i((Vector2(tile) / T).floor())):
				failures.append("%s: solid interior tile %s on the ring/outside %s" % [where, tile, room.id])
			for o in objects:
				if px.intersects(Rect2(o.position + centre, o.size)):
					failures.append("%s: interior tile %s covers a world object of %s" % [where, tile, room.id])
					break
			for walk in walks:
				var a: Vector2 = walk[0]
				var b: Vector2 = walk[1]
				var steps := ceili(a.distance_to(b) / 8.0)
				for i in steps + 1:
					if px.grow(20.0).has_point(a.lerp(b, float(i) / steps)) and Rect2(Vector2(rect.position) * 32.0, Vector2(rect.size) * 32.0).has_point(a.lerp(b, float(i) / steps)):
						failures.append("%s: interior tile %s on the walk line into %s" % [where, tile, room.id])
						break
