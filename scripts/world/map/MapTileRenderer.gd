class_name MapTileRenderer
extends Node2D

## Draws a MapLayout with tiles: Floor / Walls / Decor / Doors TileMapLayers of
## 16 px tiles scaled by ArtConfig.ART_SCALE. One logical cell = CELL_TILES x
## CELL_TILES tiles. Presentation only: RoomManager decides what is discovered
## and calls show_zone()/show_door(); nothing here holds gameplay state.
##
## build_plan() is pure and deterministic (same layout + config -> same plan),
## keyed by zone id so a zone's tiles are only painted when it is revealed:
##   {"zones": {zone_id: {"floor": {tile: Vector4i}, "walls": {...}, "decor": {...}}},
##    "doors": {corridor_id: {"tile": Vector2i, "alt": int}}}
## Tile values are DungeonTiles.tile(source, atlas, alt). Walls are the 1-cell
## ring around all floor (2 tiles thick): the row touching floor below is a
## brick face, the row above it its cap, the row touching floor above a flipped
## cap, everything else solid fill (physics layer "wall" on all of them; nothing
## masks it yet: movement is graph-based, see docs/MAP_RENDER.md).

const T := ArtConfig.CELL_TILES
const DIRS8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

@onready var floor_layer: TileMapLayer = $Floor
@onready var walls_layer: TileMapLayer = $Walls
@onready var decor_layer: TileMapLayer = $Decor
@onready var doors_layer: TileMapLayer = $Doors

var _plan: Dictionary = {}
var _shown: Dictionary = {}  # zone_id -> true


func _ready() -> void:
	scale = Vector2.ONE * ArtConfig.ART_SCALE


func build(layout: MapLayout, config: MapVisualConfig) -> void:
	_plan = build_plan(layout, config)
	_shown.clear()
	for layer in [floor_layer, walls_layer, decor_layer, doors_layer]:
		layer.clear()


func get_plan() -> Dictionary:
	return _plan


## Paints the zone's floor, walls and decor (idempotent).
func show_zone(zone_id: String) -> void:
	if _shown.has(zone_id) or not _plan.get("zones", {}).has(zone_id):
		return
	_shown[zone_id] = true
	var zone: Dictionary = _plan["zones"][zone_id]
	_paint(floor_layer, zone["floor"])
	_paint(walls_layer, zone["walls"])
	_paint(decor_layer, zone["decor"])


## Door leaf of a corridor: nothing until its origin room is visible, then
## closed, then open once the door has been opened.
func show_door(corridor_id: String, origin_visible: bool, opened: bool) -> void:
	var door: Dictionary = _plan.get("doors", {}).get(corridor_id, {})
	if door.is_empty():
		return
	if not origin_visible:
		doors_layer.erase_cell(door["tile"])
		return
	var atlas := DungeonTiles.DOOR_OPEN if opened else DungeonTiles.DOOR_CLOSED
	doors_layer.set_cell(door["tile"], DungeonTiles.SRC_SHEET, atlas, door["alt"])


func _paint(layer: TileMapLayer, tiles: Dictionary) -> void:
	for tile in tiles:
		var v: Vector4i = tiles[tile]
		layer.set_cell(tile, v.x, Vector2i(v.y, v.z), v.w)


# ─────────────────────────────────────────────
# PLAN (pure)
# ─────────────────────────────────────────────
static func build_plan(layout: MapLayout, config: MapVisualConfig) -> Dictionary:
	var zones: Dictionary = {}
	var order: Array[String] = []
	var zone_cells: Dictionary = {}
	var floor_cells: Dictionary = {}  # cell -> zone id
	for room in layout.rooms:
		_add_zone(room.id, room.get_rect(), order, zone_cells, floor_cells)
	for corridor in layout.corridors:
		_add_zone(corridor.id, corridor.get_zone_rect(), order, zone_cells, floor_cells)
	for id in order:
		zones[id] = {"floor": {}, "walls": {}, "decor": {}}

	# Wall ring: 8-neighbours of floor that are not floor; the first zone in order owns it.
	var wall_owner: Dictionary = {}
	for id in order:
		for cell in zone_cells[id]:
			for d in DIRS8:
				var n: Vector2i = cell + d
				if not floor_cells.has(n) and not wall_owner.has(n):
					wall_owner[n] = id

	var floor_tiles: Dictionary = _expand(floor_cells)
	var wall_tiles: Dictionary = _expand(wall_owner)
	_plan_floor(layout, config, zones, floor_tiles)
	_plan_walls(config, layout, zones, floor_tiles, wall_tiles)
	_plan_props(layout, config, zones, floor_tiles)

	var doors: Dictionary = {}
	for corridor in layout.corridors:
		var room_a := layout.get_room(corridor.room_a).get_rect()
		var east_west := corridor.door_cell.x < room_a.position.x or corridor.door_cell.x >= room_a.end.x
		doors[corridor.id] = {
			"tile": corridor.door_cell * T,
			"alt": DungeonTiles.ALT_TRANSPOSE if east_west else DungeonTiles.ALT_NONE,
		}
	return {"zones": zones, "doors": doors}


static func _add_zone(id: String, rect: Rect2i, order: Array[String], zone_cells: Dictionary, floor_cells: Dictionary) -> void:
	order.append(id)
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			cells.append(Vector2i(x, y))
			floor_cells[Vector2i(x, y)] = id
	zone_cells[id] = cells


## cell -> zone id  =>  tile -> zone id (each cell is T x T tiles).
static func _expand(cells: Dictionary) -> Dictionary:
	var tiles: Dictionary = {}
	for cell in cells:
		for tx in T:
			for ty in T:
				tiles[cell * T + Vector2i(tx, ty)] = cells[cell]
	return tiles


static func _room_ids(layout: MapLayout) -> Dictionary:
	var ids: Dictionary = {}
	for room in layout.rooms:
		ids[room.id] = true
	return ids


static func _plan_floor(layout: MapLayout, config: MapVisualConfig, zones: Dictionary, floor_tiles: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, "floor"])
	var room_ids := _room_ids(layout)
	for tile in floor_tiles:
		var id: String = floor_tiles[tile]
		var variants := DungeonTiles.FLOOR_ROOM_VARIANTS if room_ids.has(id) else DungeonTiles.FLOOR_CORRIDOR_VARIANTS
		var atlas := DungeonTiles.FLOOR_PLAIN
		if rng.randf() < config.floor_variant_chance:
			atlas = variants[rng.randi() % variants.size()]
		zones[id]["floor"][tile] = DungeonTiles.tile(DungeonTiles.SRC_SHEET, atlas)
	# The exit room's centre cell is stairs (drawn with the room, so only once discovered).
	for room in layout.rooms:
		if room.is_exit:
			var center := (room.pos + room.size / 2) * T
			for tx in T:
				for ty in T:
					zones[room.id]["floor"][center + Vector2i(tx, ty)] = DungeonTiles.tile(DungeonTiles.SRC_SHEET, DungeonTiles.STAIRS)


static func _plan_walls(config: MapVisualConfig, layout: MapLayout, zones: Dictionary, floor_tiles: Dictionary, wall_tiles: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, "banners"])
	var room_ids := _room_ids(layout)
	var down := Vector2i(0, 1)
	var left := Vector2i(-1, 0)
	var right := Vector2i(1, 0)
	for tile in wall_tiles:
		var owner_id: String = wall_tiles[tile]
		var value := DungeonTiles.tile(DungeonTiles.SRC_FILL, DungeonTiles.WALL_FILL)
		if floor_tiles.has(tile + down):
			# Brick face; run ends get end pieces, some room faces get banners.
			var atlas := DungeonTiles.WALL_MID
			var run_left: bool = wall_tiles.has(tile + left) and floor_tiles.has(tile + left + down)
			var run_right: bool = wall_tiles.has(tile + right) and floor_tiles.has(tile + right + down)
			if not run_left:
				atlas = DungeonTiles.WALL_LEFT
			elif not run_right:
				atlas = DungeonTiles.WALL_RIGHT
			elif room_ids.has(owner_id) and rng.randf() < config.wall_decor_density:
				atlas = DungeonTiles.BANNERS[rng.randi() % DungeonTiles.BANNERS.size()]
			value = DungeonTiles.tile(DungeonTiles.SRC_SHEET, atlas)
		elif wall_tiles.has(tile + down) and floor_tiles.has(tile + down + down):
			# Cap above a face row.
			var atlas := DungeonTiles.WALL_TOP_MID
			var run_left: bool = wall_tiles.has(tile + left) and floor_tiles.has(tile + left + down + down)
			var run_right: bool = wall_tiles.has(tile + right) and floor_tiles.has(tile + right + down + down)
			if not run_left:
				atlas = DungeonTiles.WALL_TOP_LEFT
			elif not run_right:
				atlas = DungeonTiles.WALL_TOP_RIGHT
			value = DungeonTiles.tile(DungeonTiles.SRC_SHEET, atlas)
		elif floor_tiles.has(tile - down):
			# South wall: cap flipped so its edge meets the floor above.
			value = DungeonTiles.tile(DungeonTiles.SRC_SHEET, DungeonTiles.WALL_TOP_MID, DungeonTiles.ALT_FLIP_V)
		zones[owner_id]["walls"][tile] = value


## Kenney props on each room's outermost floor-tile ring (never beside a
## corridor mouth). The centre stays free for build slots / the Nexo. (LOOT
## rooms' chest is a floating Pickup spawned on discovery, not a tile.)
static func _plan_props(layout: MapLayout, config: MapVisualConfig, zones: Dictionary, floor_tiles: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, "decor"])
	for room in layout.rooms:
		var rect := Rect2i(room.pos * T, room.size * T)
		var ring: Array[Vector2i] = []
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var on_ring := x == rect.position.x or y == rect.position.y or x == rect.end.x - 1 or y == rect.end.y - 1
				if on_ring and not _touches_outside_floor(Vector2i(x, y), rect, floor_tiles):
					ring.append(Vector2i(x, y))
		var decor: Dictionary = zones[room.id]["decor"]
		for tile in ring:
			if rng.randf() < config.prop_density:
				decor[tile] = DungeonTiles.tile(DungeonTiles.SRC_PROPS, DungeonTiles.PROPS[rng.randi() % DungeonTiles.PROPS.size()])


static func _touches_outside_floor(tile: Vector2i, rect: Rect2i, floor_tiles: Dictionary) -> bool:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = tile + d
		if not rect.has_point(n) and floor_tiles.has(n):
			return true
	return false
