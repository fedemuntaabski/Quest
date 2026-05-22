extends Node
class_name DungeonPresentationManager

var map_renderer: DungeonMapRenderer
var fog_manager: FogOfWarManager
var generator: DungeonGenerator

func setup(parent: Node, generator: DungeonGenerator) -> void:
	self.generator = generator
	map_renderer = parent.get_node_or_null("TileRenderer") as DungeonMapRenderer
	if map_renderer == null:
		map_renderer = DungeonTileRenderer.new()
		map_renderer.name = "TileRenderer"
		parent.add_child(map_renderer)

	fog_manager = get_node_or_null("FogOfWarManager") as FogOfWarManager
	if fog_manager == null:
		fog_manager = FogOfWarManager.new()
		fog_manager.name = "FogOfWarManager"
		add_child(fog_manager)

	if generator and generator.room_system and not generator.room_system.room_changed.is_connected(Callable(self, "_on_room_changed")):
		generator.room_system.room_changed.connect(Callable(self, "_on_room_changed"))

	# Add visual feedback manager to the presentation layer so camera and actors can use it
	# VisualFeedback authority: use UI layer implementation (scripts/ui/visual/VisualFeedback.gd)
	var vf := get_node_or_null("VisualFeedback")
	if vf == null:
		var VisualFeedbackClass = preload("res://scripts/ui/visual/VisualFeedback.gd")
		vf = VisualFeedbackClass.new()
		vf.name = "VisualFeedback"
		add_child(vf)

func _on_room_changed(room_id: int) -> void:
	if fog_manager == null:
		return

	if generator == null:
		return

	fog_manager.update_room_state(generator.room_infos, room_id)

func build(tileset: TileSet, wall_texture: Texture2D) -> void:
	if generator == null:
		push_error("DungeonPresentationManager: generator is missing.")
		return

	if generator.room_factory == null:
		push_error("DungeonPresentationManager: room_factory is missing.")
		return

	var graph := generator.get_dungeon_graph()
	if graph == null:
		push_error("DungeonPresentationManager: dungeon graph is missing.")
		return

	for index in range(generator.room_infos.size()):
		var room_info: Dictionary = generator.room_infos[index]
		var room_nodes := generator.room_factory.create_room_nodes(
			room_info,
			generator.rooms_root,
			generator.room_lights_root,
			generator.room_detectors_root
		)
		room_info["visual_root"] = room_nodes.get("visual_root", null)
		room_info["light"] = room_nodes.get("light", null)
		room_info["area"] = room_nodes.get("area", null)
		generator.room_infos[index] = room_info

	for edge_info in graph.get_edge_records_sorted():
		var corridor_node := generator.room_factory.create_corridor_entity(edge_info, generator.corridors_root)
		graph.set_edge_runtime_node(int(edge_info.get("room_a", -1)), int(edge_info.get("room_b", -1)), corridor_node)

	map_renderer.setup(generator, tileset, generator.grid_origin)
	map_renderer.set_data(generator.floor_cells, generator.wall_cells)
	map_renderer.build()

	fog_manager.setup(
		generator,
		generator.floor_cells,
		generator.grid_origin,
		generator.tile_size,
		wall_texture
	)
	fog_manager.build()
