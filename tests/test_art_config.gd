extends SceneTree

## Guards ArtConfig.CELL_PX == tileset tile_size == RoomManager.DEFAULT_TILE_SIZE. Run:
##   godot --headless --path . --script res://tests/test_art_config.gd

func _init() -> void:
	var tileset := load("res://resources/tileset/placeholder_tileset.tres") as TileSet
	var cell := Vector2i(ArtConfig.CELL_PX, ArtConfig.CELL_PX)
	var ok := tileset != null and tileset.tile_size == cell \
		and Vector2i(preload("res://scripts/world/RoomManager.gd").DEFAULT_TILE_SIZE) == cell
	print("art config: CELL_PX=%d tileset=%s ok=%s" % [ArtConfig.CELL_PX, tileset.tile_size if tileset else "null", ok])
	quit(0 if ok else 1)
