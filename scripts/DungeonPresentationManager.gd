extends Node
class_name DungeonPresentationManager

var tile_renderer: DungeonTileRenderer
var fog_manager: FogOfWarManager
var fog_controller: DungeonFogController

func setup(parent: Node, generator: DungeonGenerator) -> void:
	tile_renderer = DungeonTileRenderer.new()
	tile_renderer.name = "TileRenderer"
	parent.add_child(tile_renderer)

	fog_manager = FogOfWarManager.new()
	add_child(fog_manager)

	fog_controller = DungeonFogController.new()
	add_child(fog_controller)
	fog_controller.setup(generator, fog_manager)

func build(generator: DungeonGenerator, tileset: TileSet, wall_texture: Texture2D) -> void:
	tile_renderer.setup(generator, tileset, generator.grid_origin)
	tile_renderer.set_data(generator.floor_cells, generator.wall_cells)
	tile_renderer.build()

	fog_manager.setup(
		generator,
		generator.floor_cells,
		generator.grid_origin,
		generator.tile_size,
		wall_texture
	)
	fog_manager.build()
