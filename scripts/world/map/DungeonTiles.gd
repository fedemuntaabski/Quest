class_name DungeonTiles
extends RefCounted

## Atlas coordinates of every tile MapTileRenderer uses (16 px grid). Single
## source of truth shared by tools/build_tilesets.gd (which bakes the .tres)
## and MapTileRenderer. Coordinates = tile_list_v1.7 x/y divided by 16.
## Tiles are Vector4i(source_id, atlas_x, atlas_y, alternative) via tile().

# dungeon_tileset.tres sources
const SRC_SHEET := 0  # 0x72 full sheet
const SRC_FILL := 1   # atlas_walls_low: solid (34,34,34) tile at (9,2)
# props_tileset.tres source (Kenney tilemap_packed)
const SRC_PROPS := 0

const ALT_NONE := 0
const ALT_FLIP_V := 1     # wall tiles: cap of a south wall
const ALT_TRANSPOSE := 1  # door leaf on E-W corridors

const FLOOR_PLAIN := Vector2i(1, 4)                       # floor_1
const FLOOR_ROOM_VARIANTS: Array[Vector2i] = [            # floor_2,3 cracks; 4 rune; 5,6 marks; 7,8 stains
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(1, 6), Vector2i(2, 6)]
const FLOOR_CORRIDOR_VARIANTS: Array[Vector2i] = [Vector2i(2, 4), Vector2i(3, 4)]  # cracks only

const WALL_TOP_LEFT := Vector2i(1, 0)
const WALL_TOP_MID := Vector2i(2, 0)
const WALL_TOP_RIGHT := Vector2i(3, 0)
const WALL_LEFT := Vector2i(1, 1)
const WALL_MID := Vector2i(2, 1)
const WALL_RIGHT := Vector2i(3, 1)
const WALL_FILL := Vector2i(9, 2)  # in SRC_FILL

const BANNERS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 3)]  # red, blue, green, yellow (face tiles)

const STAIRS := Vector2i(5, 12)     # floor_stairs
const DOOR_CLOSED := Vector2i(2, 15)  # doors_leaf_closed, 2x2 tiles
const DOOR_OPEN := Vector2i(5, 15)    # doors_leaf_open, 2x2 tiles

# props_tileset.tres (Kenney)
const PROPS: Array[Vector2i] = [Vector2i(3, 5), Vector2i(3, 6), Vector2i(4, 5), Vector2i(5, 5), Vector2i(2, 6), Vector2i(6, 5)]
const CHEST := Vector2i(5, 7)


static func tile(source: int, atlas: Vector2i, alt: int = ALT_NONE) -> Vector4i:
	return Vector4i(source, atlas.x, atlas.y, alt)
