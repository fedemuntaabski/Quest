class_name ArtConfig
extends RefCounted

## Single source of truth for pixel-art scale. Source art is 16x16 px tiles
## (Kenney / Tiny Creatures / 0x72). One logical map cell (MapLayout/MapGenerator)
## = CELL_TILES x CELL_TILES art tiles, each drawn at ART_SCALE, so CELL_PX must
## equal the tile_size in resources/tilesets/placeholder_tileset.tres (the logical
## grid layer) and RoomManager.DEFAULT_TILE_SIZE (tests/test_art_config.gd guards it).
## Changing ART_SCALE or CELL_TILES means keeping CELL_PX == 64 or updating both.
const TILE_SIZE := 16
const ART_SCALE := 2
const CELL_TILES := 2
const CELL_PX := TILE_SIZE * ART_SCALE * CELL_TILES  # 64: world px of one logical cell
