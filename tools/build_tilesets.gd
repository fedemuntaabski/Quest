extends SceneTree

## Bakes assets/tilesets/{dungeon,props}_tileset.tres from DungeonTiles' atlas
## coordinates. Re-run after changing them:
##   godot --headless --path . --script res://tools/build_tilesets.gd
## Physics layer 0 (collision layer 16 = "wall", mask 0) only on wall tiles.

const SHEET := "res://assets/art/_source/0x72_DungeonTilesetII_v1.7/0x72_DungeonTilesetII_v1.7.png"
const FILL := "res://assets/art/tiles/atlas_walls_low-16x16.png"
const KENNEY := "res://assets/art/_source/kenney_tinyDungeon/Tilemap/tilemap_packed.png"
const WALL_LAYER_BIT := 16


func _init() -> void:
	_build_dungeon()
	_build_props()
	quit()


func _new_tileset(physics: bool) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	if physics:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, WALL_LAYER_BIT)
		ts.set_physics_layer_collision_mask(0, 0)
	return ts


## Added to the TileSet *before* tiles are created: TileData only knows the
## TileSet's physics layers once its source belongs to it.
func _source(ts: TileSet, id: int, path: String) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, id)
	return src


func _add(src: TileSetAtlasSource, coords: Vector2i, size := Vector2i.ONE) -> TileData:
	src.create_tile(coords, size)
	return src.get_tile_data(coords, 0)


func _solid(data: TileData) -> void:
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))


func _build_dungeon() -> void:
	var ts := _new_tileset(true)

	var sheet := _source(ts, DungeonTiles.SRC_SHEET, SHEET)
	# Floors (plain weighted heavier; variants rarer).
	_add(sheet, DungeonTiles.FLOOR_PLAIN).probability = 6.0
	for coords in DungeonTiles.FLOOR_ROOM_VARIANTS:
		_add(sheet, coords).probability = 1.0
	# Walls: solid, with a flip_v alternative for the cap of a south wall.
	for coords in [DungeonTiles.WALL_TOP_LEFT, DungeonTiles.WALL_TOP_MID, DungeonTiles.WALL_TOP_RIGHT, DungeonTiles.WALL_LEFT, DungeonTiles.WALL_MID, DungeonTiles.WALL_RIGHT]:
		_solid(_add(sheet, coords))
	sheet.create_alternative_tile(DungeonTiles.WALL_TOP_MID, DungeonTiles.ALT_FLIP_V)
	sheet.get_tile_data(DungeonTiles.WALL_TOP_MID, DungeonTiles.ALT_FLIP_V).flip_v = true
	_solid(sheet.get_tile_data(DungeonTiles.WALL_TOP_MID, DungeonTiles.ALT_FLIP_V))
	# Wall decoration (drawn on the Decor layer over a face tile: no physics).
	for coords in DungeonTiles.BANNERS:
		_add(sheet, coords)
	_add(sheet, DungeonTiles.STAIRS)
	# Doors: 2x2 tiles, transposed alternative for E-W corridors.
	for coords in [DungeonTiles.DOOR_CLOSED, DungeonTiles.DOOR_OPEN]:
		_add(sheet, coords, Vector2i(2, 2))
		sheet.create_alternative_tile(coords, DungeonTiles.ALT_TRANSPOSE)
		sheet.get_tile_data(coords, DungeonTiles.ALT_TRANSPOSE).transpose = true

	var fill := _source(ts, DungeonTiles.SRC_FILL, FILL)
	_solid(_add(fill, DungeonTiles.WALL_FILL))

	print("dungeon_tileset save: ", error_string(ResourceSaver.save(ts, "res://assets/tilesets/dungeon_tileset.tres")))


func _build_props() -> void:
	var ts := _new_tileset(false)
	var src := _source(ts, DungeonTiles.SRC_PROPS, KENNEY)
	for coords in DungeonTiles.PROPS:
		_add(src, coords)
	_add(src, DungeonTiles.CHEST)
	print("props_tileset save: ", error_string(ResourceSaver.save(ts, "res://assets/tilesets/props_tileset.tres")))
