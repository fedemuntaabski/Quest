class_name MapTileRenderer
extends Node2D

## Draws a MapLayout with tiles: Floor / Walls / Decor TileMapLayers of
## 16 px tiles scaled by ArtConfig.ART_SCALE. One logical cell = CELL_TILES x
## CELL_TILES tiles. Presentation only: RoomManager decides what is discovered
## and calls show_zone(); nothing here holds gameplay state. Door leaves are not
## tiles: a multi-cell atlas tile is drawn centered on its origin cell, which
## shifted them off the corridor lane; Door.tscn owns its own centered Sprite2D.
##
## build_plan() is pure and deterministic (same layout + config -> same plan),
## keyed by zone id so a zone's tiles are only painted when it is revealed:
##   {"zones": {zone_id: {"floor": {tile: Vector4i}, "walls": {...}, "decor": {...}, "under": {...}, "features": {...},
##                        "flat": {...}, "wall_decor": {...}, "lights": [[tile, kind], ...]}}}
## mazmorra-32 (_plan_dressing): "wall_decor" = torches, shelves, chains over a room's north brick
## face; "flat" = cobwebs, cracks, puddles, blood, moss (no footprint, may sit on the edge ring);
## both go on the Features layer. "lights" = torch / brazier / candles tiles, where RoomLight-style
## flames are lit (see docs/MAP_RENDER.md).
## "features" (mazmorra-31) = interior pieces over the floor (columns, rubble) on their own
## layer; pits, rugs and paved slabs replace "floor" tiles. See _plan_interior().
## "under" (juego-21) = solid fill painted on the Floor layer behind wall caps: a cap's
## upper half is transparent, so without it the grey side columns stuck out above the
## north lip at every corner; with it the whole wall mass reads as one block.
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
@onready var features_layer: TileMapLayer = $Features
@onready var decor_layer: TileMapLayer = $Decor

var _plan: Dictionary = {}
var _shown: Dictionary = {}  # zone_id -> true


func _ready() -> void:
	scale = Vector2.ONE * ArtConfig.ART_SCALE


func build(layout: MapLayout, config: MapVisualConfig) -> void:
	_plan = build_plan(layout, config)
	_shown.clear()
	for layer in [floor_layer, walls_layer, features_layer, decor_layer]:
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
	_paint(features_layer, zone["features"])
	_paint(features_layer, zone["flat"])
	_paint(features_layer, zone["wall_decor"])
	_paint(decor_layer, zone["decor"])
	_paint(floor_layer, zone["under"])


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
		_add_zone(room.id, room.get_cells(), order, zone_cells, floor_cells)
	for corridor in layout.corridors:
		_add_zone(corridor.id, _rect_cells(corridor.get_zone_rect()), order, zone_cells, floor_cells)
	for id in order:
		zones[id] = {"floor": {}, "walls": {}, "decor": {}, "under": {}, "features": {}, "flat": {}, "wall_decor": {}, "lights": []}

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
	_plan_interior(layout, config, zones)
	_plan_props(layout, config, zones, floor_tiles)
	_plan_dressing(layout, config, zones, floor_tiles)

	return {"zones": zones}


static func _add_zone(id: String, cells: Array[Vector2i], order: Array[String], zone_cells: Dictionary, floor_cells: Dictionary) -> void:
	order.append(id)
	for cell in cells:
		floor_cells[cell] = id
	zone_cells[id] = cells


static func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			cells.append(Vector2i(x, y))
	return cells


## Room tile on its own edge: a 4-neighbour is outside the room's shape (wall, cut-out or corridor).
static func _room_edge(room: RoomData, tile: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if not room.has_cell(_cell_of(tile + d)):
			return true
	return false


static func _cell_of(tile: Vector2i) -> Vector2i:
	return Vector2i((Vector2(tile) / T).floor())


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
	# The exit room's stairs: the cell below the centre one (mazmorra-31: the centre holds the
	# build slot and the exit marker); drawn with the room, so only once discovered. That cell
	# is on the centre column, which a shape never cuts.
	for room in layout.rooms:
		if room.is_exit:
			var center := (room.pos + room.size / 2 + Vector2i(0, 1)) * T
			for tx in T:
				for ty in T:
					zones[room.id]["floor"][center + Vector2i(tx, ty)] = DungeonTiles.tile(DungeonTiles.SRC_SHEET, DungeonTiles.STAIRS)


static func _plan_walls(config: MapVisualConfig, layout: MapLayout, zones: Dictionary, floor_tiles: Dictionary, wall_tiles: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, "banners"])
	# Own stream (juego-21): worn bricks never move the banners of an existing seed.
	var wear_rng := RandomNumberGenerator.new()
	wear_rng.seed = hash([layout.map_seed, "wall_wear"])
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
			elif wear_rng.randf() < config.wall_wear_density:
				atlas = DungeonTiles.WALL_WEAR[wear_rng.randi() % DungeonTiles.WALL_WEAR.size()]
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
			zones[owner_id]["under"][tile] = DungeonTiles.tile(DungeonTiles.SRC_FILL, DungeonTiles.WALL_FILL)
		elif floor_tiles.has(tile - down):
			# South wall: cap flipped so its edge meets the floor above.
			value = DungeonTiles.tile(DungeonTiles.SRC_SHEET, DungeonTiles.WALL_TOP_MID, DungeonTiles.ALT_FLIP_V)
			zones[owner_id]["under"][tile] = DungeonTiles.tile(DungeonTiles.SRC_FILL, DungeonTiles.WALL_FILL)
		zones[owner_id]["walls"][tile] = value


## Kenney props on each room's outermost floor-tile ring (never beside a
## corridor mouth). The centre stays free for build slots / the Relic. (LOOT
## rooms' chest is a floating Pickup spawned on discovery, not a tile.)
static func _plan_props(layout: MapLayout, config: MapVisualConfig, zones: Dictionary, floor_tiles: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.map_seed, "decor"])
	# Own stream: type props never move the generic ones.
	var type_rng := RandomNumberGenerator.new()
	type_rng.seed = hash([layout.map_seed, "type_decor"])
	for room in layout.rooms:
		var rect := Rect2i(room.pos * T, room.size * T)
		var ring: Array[Vector2i] = []
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var tile := Vector2i(x, y)
				if room.has_cell(_cell_of(tile)) and _room_edge(room, tile) and not _touches_outside_floor(tile, room, floor_tiles):
					ring.append(tile)
		var decor: Dictionary = zones[room.id]["decor"]
		for tile in ring:
			if rng.randf() < config.prop_density:
				decor[tile] = DungeonTiles.tile(DungeonTiles.SRC_PROPS, DungeonTiles.PROPS[rng.randi() % DungeonTiles.PROPS.size()])
		# Special rooms: their own props (RoomTypeVisual.decor_props) on the same ring.
		var visual := config.room_type_visual(room.get_room_type())
		if visual and not visual.decor_props.is_empty() and not ring.is_empty():
			for i in mini(visual.decor_count, ring.size()):
				var tile: Vector2i = ring[type_rng.randi() % ring.size()]
				decor[tile] = DungeonTiles.tile(DungeonTiles.SRC_PROPS, visual.decor_props[type_rng.randi() % visual.decor_props.size()])


static func _touches_outside_floor(tile: Vector2i, room: RoomData, floor_tiles: Dictionary) -> bool:
	for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = tile + d
		if not room.has_cell(_cell_of(n)) and floor_tiles.has(n):
			return true
	return false


# ─────────────────────────────────────────────
# INTERIOR (mazmorra-31)
# ─────────────────────────────────────────────
enum Interior { NONE, COLUMNS, PIT, RUG, SLABS }
## Relative odds of each room's template (a template that finds no room to fit leaves it plain).
const INTERIOR_WEIGHTS := {Interior.NONE: 2, Interior.COLUMNS: 3, Interior.PIT: 2, Interior.RUG: 2, Interior.SLABS: 2}
## Centre block kept clear of solid pieces, in tiles from the room centre (= -64..+64 px x,
## -128..+64 px y): build slots, Relic / chest (-56), cage (-40), altar, heroes standing there.
const CENTRE_BLOCK := Rect2i(-2, -4, 4, 6)
## Top tile rows kept clear: the type badge (top-left) and the light icon (top-right).
const TOP_BAND := 2
## Tiles (of 32 px) kept clear either side of a walk line: 24 px.
const WALK_MARGIN := 0.75
const RUG_MAX := Vector2i(8, 6)


## One template per room on its own RNG (seed, "interior", room id), so a room's look never
## depends on the others; plus loose rubble. Solid pieces (columns, pits, rubble) never sit
## on interior_blocked() tiles; rugs and slabs are floor, so they may run under the centre.
static func _plan_interior(layout: MapLayout, config: MapVisualConfig, zones: Dictionary) -> void:
	for room in layout.rooms:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([layout.map_seed, "interior", room.id])
		var rect := Rect2i(room.pos * T, room.size * T)
		var blocked := interior_blocked(layout, room)
		var zone: Dictionary = zones[room.id]
		for tile in zone["floor"]:  # the exit stairs stay clear
			if Vector2i(zone["floor"][tile].y, zone["floor"][tile].z) == DungeonTiles.STAIRS:
				blocked[tile] = true
		var kind := _pick_interior(rng)  # always rolled: forcing a type never shifts the stream
		var visual := config.room_type_visual(room.get_room_type()) if config else null
		if visual and visual.interior >= 0:
			kind = visual.interior as Interior
		match kind:
			Interior.COLUMNS: _plan_columns(rect, blocked, zone)
			Interior.PIT: _plan_pit(rect, blocked, zone, rng)
			Interior.RUG: _plan_rug(room, rect, zone)
			Interior.SLABS: _plan_slabs(layout, room, zone, rng)
		_plan_rubble(rect, blocked, zone, rng)


static func _pick_interior(rng: RandomNumberGenerator) -> Interior:
	var total := 0
	for w in INTERIOR_WEIGHTS.values():
		total += w
	var roll := rng.randi_range(1, total)
	for kind in INTERIOR_WEIGHTS:
		roll -= INTERIOR_WEIGHTS[kind]
		if roll <= 0:
			return kind
	return Interior.NONE


## Tiles of the room where nothing solid may go: cut-outs and the edge tile ring (props, corridor
## mouths), the top band, the centre block and every tile within WALK_MARGIN of the walk
## line heroes tween along (corridor zone centre -> room centre, MoveAction).
static func interior_blocked(layout: MapLayout, room: RoomData) -> Dictionary:
	var rect := Rect2i(room.pos * T, room.size * T)
	var blocked: Dictionary = {}
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var tile := Vector2i(x, y)
			if y < rect.position.y + TOP_BAND or not room.has_cell(_cell_of(tile)) or _room_edge(room, tile):
				blocked[tile] = true
	var centre := rect.position + rect.size / 2
	for x in range(CENTRE_BLOCK.position.x, CENTRE_BLOCK.end.x):
		for y in range(CENTRE_BLOCK.position.y, CENTRE_BLOCK.end.y):
			blocked[centre + Vector2i(x, y)] = true
	var room_centre := (Vector2(room.pos) + Vector2(room.size) / 2.0) * T
	for corridor in layout.corridors:
		if corridor.room_a != room.id and corridor.room_b != room.id:
			continue
		var zr := corridor.get_zone_rect()
		var from := (Vector2(zr.position) + Vector2(zr.size) / 2.0) * T
		var steps := ceili(from.distance_to(room_centre) * 4.0)  # every 1/4 tile (8 px)
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var grown := Rect2(Vector2(x, y), Vector2.ONE).grow(WALK_MARGIN)
				for i in steps + 1:
					if grown.has_point(from.lerp(room_centre, float(i) / steps)):
						blocked[Vector2i(x, y)] = true
						break
	return blocked


## Cells of the room from each corridor mouth straight to the centre cell (paved slabs).
static func lane_cells(layout: MapLayout, room: RoomData) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var room_rect := room.get_rect()
	var centre := room.pos + room.size / 2
	for corridor in layout.corridors:
		if corridor.room_a != room.id and corridor.room_b != room.id:
			continue
		var zr := corridor.get_zone_rect()
		for x in range(zr.position.x, zr.end.x):
			for y in range(zr.position.y, zr.end.y):
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var entry := Vector2i(x, y) + d
					if not room_rect.has_point(entry):
						continue
					# Along the entry axis first, then across to the centre.
					var cell := entry
					cells.append(cell)
					while cell != centre:
						if (d.x != 0 and cell.x != centre.x) or cell.y == centre.y:
							cell.x += signi(centre.x - cell.x)
						else:
							cell.y += signi(centre.y - cell.y)
						cells.append(cell)
	return cells


static func _free(blocked: Dictionary, tiles: Array) -> bool:
	for tile in tiles:
		if blocked.has(tile):
			return false
	return true


## Two columns (0x72 column, 3 tiles tall) mirrored left/right, low pair first, a high
## pair too if it fits and doesn't touch the low one.
static func _plan_columns(rect: Rect2i, blocked: Dictionary, zone: Dictionary) -> void:
	var xs := [rect.position.x + 2, rect.end.x - 3]
	var placed_bases: Array[int] = []
	for base in [rect.end.y - 3, rect.position.y + TOP_BAND + 2]:
		if placed_bases.any(func(b: int) -> bool: return absi(b - base) < 4):
			continue
		var footprint: Array = []
		for x in xs:
			footprint.append_array([Vector2i(x, base - 2), Vector2i(x, base - 1), Vector2i(x, base)])
		if not _free(blocked, footprint):
			continue
		placed_bases.append(base)
		for x in xs:
			for i in DungeonTiles.COLUMN.size():
				zone["features"][Vector2i(x, base - 2 + i)] = DungeonTiles.tile(DungeonTiles.SRC_SHEET, DungeonTiles.COLUMN[i])


## One 1-cell pit (2x2 tiles) on a free spot with a free tile all around it.
static func _plan_pit(rect: Rect2i, blocked: Dictionary, zone: Dictionary, rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x - 1):
		for y in range(rect.position.y, rect.end.y - 1):
			var around: Array = []
			for dx in range(-1, 3):
				for dy in range(-1, 3):
					around.append(Vector2i(x + dx, y + dy))
			if _free(blocked, around):
				spots.append(Vector2i(x, y))
	# Big rooms (>= 30 cells) may get a second pit, never next to the first.
	for n in (2 if rect.get_area() >= 30 * T * T else 1):
		if spots.is_empty():
			return
		var at := spots[rng.randi() % spots.size()]
		for i in 4:
			zone["floor"][at + Vector2i(i % 2, i / 2)] = DungeonTiles.tile(DungeonTiles.SRC_OWN, DungeonTiles.PIT[i])
		spots = spots.filter(func(s: Vector2i) -> bool: return absi(s.x - at.x) > 3 or absi(s.y - at.y) > 3)


## Rug centred on the room, 2-tile margin, at most RUG_MAX tiles (needs 4x4); never over the stairs.
## The rug and a 1-tile margin around it stay inside the room's shape (cut corners).
static func _rug_fits(room: RoomData, rug: Rect2i) -> bool:
	for x in range(rug.position.x - 1, rug.end.x + 1):
		for y in range(rug.position.y - 1, rug.end.y + 1):
			if not room.has_cell(_cell_of(Vector2i(x, y))):
				return false
	return true


static func _plan_rug(room: RoomData, rect: Rect2i, zone: Dictionary) -> void:
	var size := (rect.size - Vector2i(4, 4)).min(RUG_MAX)
	var rug := Rect2i(rect.position + (rect.size - size) / 2, size)
	while size.x >= 4 and size.y >= 4 and not _rug_fits(room, rug):
		size -= Vector2i(2, 2)
		rug = Rect2i(rect.position + (rect.size - size) / 2, size)
	if size.x < 4 or size.y < 4:
		return
	for x in range(rug.position.x, rug.end.x):
		for y in range(rug.position.y, rug.end.y):
			var row := 0 if y == rug.position.y else (2 if y == rug.end.y - 1 else 1)
			var col := 0 if x == rug.position.x else (2 if x == rug.end.x - 1 else 1)
			_set_floor(zone, Vector2i(x, y), DungeonTiles.tile(DungeonTiles.SRC_OWN, DungeonTiles.RUG[row * 3 + col]))


## Paved walk: slabs on the lanes from each door to the centre cell and around it.
static func _plan_slabs(layout: MapLayout, room: RoomData, zone: Dictionary, rng: RandomNumberGenerator) -> void:
	var cells := lane_cells(layout, room)
	var centre := room.pos + room.size / 2
	for d in DIRS8:
		if room.has_cell(centre + d):
			cells.append(centre + d)
	for cell in cells:
		for tx in T:
			for ty in T:
				var slab := DungeonTiles.SLABS[rng.randi() % DungeonTiles.SLABS.size()]
				_set_floor(zone, cell * T + Vector2i(tx, ty), DungeonTiles.tile(DungeonTiles.SRC_OWN, slab))


static func _set_floor(zone: Dictionary, tile: Vector2i, value: Vector4i) -> void:
	var current: Vector4i = zone["floor"].get(tile, Vector4i(-1, 0, 0, 0))
	if current.x == -1 or (current.x == DungeonTiles.SRC_SHEET and Vector2i(current.y, current.z) == DungeonTiles.STAIRS):
		return  # not this room's floor (cut-out) or the exit stairs
	zone["floor"][tile] = value


## 1-4 rubble tiles on free floor (no feature, pit, rug or slab under them).
static func _plan_rubble(rect: Rect2i, blocked: Dictionary, zone: Dictionary, rng: RandomNumberGenerator) -> void:
	var spots: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var tile := Vector2i(x, y)
			var floor_value: Vector4i = zone["floor"].get(tile, Vector4i(-1, 0, 0, 0))
			if not blocked.has(tile) and not zone["features"].has(tile) and floor_value.x == DungeonTiles.SRC_SHEET:
				spots.append(tile)
	for i in mini(rng.randi_range(1, 4), spots.size()):
		var tile := spots[rng.randi() % spots.size()]
		zone["features"][tile] = DungeonTiles.tile(DungeonTiles.SRC_OWN, DungeonTiles.RUBBLE[rng.randi() % DungeonTiles.RUBBLE.size()])


# ─────────────────────────────────────────────
# DRESSING (mazmorra-32): own torches, braziers, wall pieces, scatter and type props
# ─────────────────────────────────────────────
## A room with no type braziers gets one with this chance.
const BRAZIER_CHANCE := 0.3
## Each of the room's two top floor corners gets a cobweb with this chance.
const COBWEB_CHANCE := 0.35
## Up to this many cracks / puddles per room, plus bones with BONES_CHANCE.
const SCATTER_MAX := 2
const BONES_CHANCE := 0.25
## A north face this many tiles wide or more gets two torches instead of one.
const TWO_TORCHES_WIDTH := 8


## Per room on its own RNG (seed, "dressing", room id), after the interior: torches on the north
## face, the type's wall pieces, braziers and solid props on free floor (never interior_blocked),
## flat scatter anywhere on plain floor. Every pick is rolled even when it finds no spot, so a
## room's stream doesn't depend on its free space.
static func _plan_dressing(layout: MapLayout, config: MapVisualConfig, zones: Dictionary, floor_tiles: Dictionary) -> void:
	for room in layout.rooms:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([layout.map_seed, "dressing", room.id])
		var zone: Dictionary = zones[room.id]
		var visual := config.room_type_visual(room.get_room_type()) if config else null
		var rect := Rect2i(room.pos * T, room.size * T)
		var centre := rect.position + rect.size / 2
		# North brick face: plain faces only (banners and run ends keep their art), left to right.
		var faces: Array[Vector2i] = []
		for tile: Vector2i in zone["walls"]:
			var v: Vector4i = zone["walls"][tile]
			if floor_tiles.get(tile + Vector2i(0, 1), "") == room.id and v.x == DungeonTiles.SRC_SHEET \
					and Vector2i(v.y, v.z) in [DungeonTiles.WALL_MID] + DungeonTiles.WALL_WEAR:
				faces.append(tile)
		faces.sort()
		var targets: Array = [centre.x] if faces.size() < TWO_TORCHES_WIDTH else [rect.position.x + rect.size.x / 4, rect.end.x - 1 - rect.size.x / 4]
		for target in targets:
			var face := _nearest(faces, Vector2i(target, rect.position.y - 1))
			if face.x != -9999:
				_put_wall(zone, faces, face, DungeonTiles.TORCH)
				zone["lights"].append([face, "torch"])
		if visual:
			for i in visual.wall_prop_count:
				var pick := rng.randi()
				if not faces.is_empty() and not visual.wall_props.is_empty():
					_put_wall(zone, faces, faces[pick % faces.size()], visual.wall_props[rng.randi() % visual.wall_props.size()])
		# Free floor for solid pieces.
		var blocked := interior_blocked(layout, room)
		var free: Array[Vector2i] = []
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var tile := Vector2i(x, y)
				var v: Vector4i = zone["floor"].get(tile, Vector4i(-1, 0, 0, 0))
				if v.x == DungeonTiles.SRC_SHEET and Vector2i(v.y, v.z) != DungeonTiles.STAIRS and not blocked.has(tile) and not zone["features"].has(tile):
					free.append(tile)
		var side := rect.size.x / 3
		var roll := rng.randf()
		var braziers: int = visual.braziers if visual and visual.braziers > 0 else (1 if roll < BRAZIER_CHANCE else 0)
		for i in braziers:
			var spot := _nearest(free, centre + Vector2i(side if i % 2 == 0 else -side, 0))
			if spot.x != -9999:
				_put_solid(zone, free, spot, DungeonTiles.BRAZIER)
				zone["lights"].append([spot, "brazier"])
		if visual:
			for i in visual.floor_prop_count:
				var prop: Vector2i = visual.floor_props[rng.randi() % visual.floor_props.size()] if not visual.floor_props.is_empty() else Vector2i(-1, -1)
				var pick := rng.randi()
				if prop == Vector2i(-1, -1):
					continue
				if prop in DungeonTiles.FLAT:
					_put_flat(zone, prop, pick, free)
				elif prop == DungeonTiles.CANDLES:  # around the altar: nearest free tile to the centre, alternating sides
					var spot := _nearest(free, centre + Vector2i(3 if i % 2 == 0 else -3, -1))
					if spot.x != -9999:
						_put_solid(zone, free, spot, prop)
						zone["lights"].append([spot, "candles"])
				elif prop == DungeonTiles.BEDROLL[0]:
					var pairs := free.filter(func(t: Vector2i) -> bool: return free.has(t + Vector2i(1, 0)))
					if not pairs.is_empty():
						var at: Vector2i = pairs[pick % pairs.size()]
						_put_solid(zone, free, at, DungeonTiles.BEDROLL[0])
						_put_solid(zone, free, at + Vector2i(1, 0), DungeonTiles.BEDROLL[1])
				elif not free.is_empty():
					_put_solid(zone, free, free[pick % free.size()], prop)
		# Generic scatter: cobwebs in the top corners, cracks / puddles, sometimes bones.
		for corner in [rect.position, Vector2i(rect.end.x - 1, rect.position.y)]:
			if rng.randf() < COBWEB_CHANCE and zone["floor"].has(corner) and not zone["decor"].has(corner):
				zone["flat"][corner] = DungeonTiles.tile(DungeonTiles.SRC_OWN, DungeonTiles.COBWEB_L if corner == rect.position else DungeonTiles.COBWEB_R)
		for i in rng.randi_range(0, SCATTER_MAX):
			var kinds: Array = DungeonTiles.CRACKS + [DungeonTiles.PUDDLE]
			_put_flat(zone, kinds[rng.randi() % kinds.size()], rng.randi(), free)
		var bone_roll := rng.randf()
		var bone_pick := rng.randi()
		if bone_roll < BONES_CHANCE and not free.is_empty():
			_put_solid(zone, free, free[bone_pick % free.size()], DungeonTiles.BONES[bone_pick % DungeonTiles.BONES.size()])


## Tile of `tiles` nearest to `to` (first one on ties); Vector2i(-9999, ...) when empty.
static func _nearest(tiles: Array[Vector2i], to: Vector2i) -> Vector2i:
	var best := Vector2i(-9999, -9999)
	var best_d := INF
	for t in tiles:
		var d := Vector2(t - to).length_squared()
		if d < best_d:
			best_d = d
			best = t
	return best


## A wall piece on `face`; it and its two neighbours leave the face list (no touching pieces).
static func _put_wall(zone: Dictionary, faces: Array[Vector2i], face: Vector2i, atlas: Vector2i) -> void:
	zone["wall_decor"][face] = DungeonTiles.tile(DungeonTiles.SRC_OWN, atlas)
	for dx in [-1, 0, 1]:
		faces.erase(face + Vector2i(dx, 0))


## A solid piece on `spot`; it and its 8 neighbours leave the free list (pieces never touch).
static func _put_solid(zone: Dictionary, free: Array[Vector2i], spot: Vector2i, atlas: Vector2i) -> void:
	zone["features"][spot] = DungeonTiles.tile(DungeonTiles.SRC_OWN, atlas)
	for d in DIRS8 + [Vector2i.ZERO]:
		if spot + d != spot + Vector2i(1, 0) or atlas != DungeonTiles.BEDROLL[0]:  # the bedroll's right half
			free.erase(spot + d)


## A flat piece on a plain floor tile of the room with nothing on it (`pick` chooses which).
static func _put_flat(zone: Dictionary, atlas: Vector2i, pick: int, free: Array[Vector2i]) -> void:
	var spots: Array[Vector2i] = []
	for tile: Vector2i in zone["floor"]:
		var v: Vector4i = zone["floor"][tile]
		if v.x == DungeonTiles.SRC_SHEET and Vector2i(v.y, v.z) != DungeonTiles.STAIRS and not zone["features"].has(tile) \
				and not zone["flat"].has(tile) and not zone["decor"].has(tile):
			spots.append(tile)
	if not spots.is_empty():
		spots.sort()
		var spot := spots[pick % spots.size()]
		zone["flat"][spot] = DungeonTiles.tile(DungeonTiles.SRC_OWN, atlas)
		free.erase(spot)  # no solid piece on top of it later
