class_name ArtConfig
extends RefCounted

## Single source of truth for pixel-art scale. Source art is 16x16 px tiles
## (Kenney / Tiny Creatures / 0x72); one logical map cell (MapLayout/MapGenerator)
## is one art tile drawn at ART_SCALE, so CELL_PX must equal the tile_size in
## resources/tileset/placeholder_tileset.tres and RoomManager.DEFAULT_TILE_SIZE
## (tests/test_art_config.gd guards this). Changing ART_SCALE means updating both.
const TILE_SIZE := 16
const ART_SCALE := 4
const CELL_PX := TILE_SIZE * ART_SCALE  # 64: world px of one logical cell


## World px for a length given in art pixels (e.g. a 16x28 sprite).
static func art_px(px: float) -> float:
	return px * ART_SCALE
