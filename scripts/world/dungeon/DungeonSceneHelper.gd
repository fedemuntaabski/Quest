extends RefCounted
class_name DungeonSceneHelper

var dungeon: DungeonGenerator = null

func setup(p_dungeon: DungeonGenerator) -> void:
	dungeon = p_dungeon

func ensure_scene_roots() -> void:
	if dungeon == null:
		return

	dungeon.corridors_root = ensure_node("Corridors")
	dungeon.rooms_root = ensure_node("Rooms")
	dungeon.walls_root = ensure_node("Walls")
	dungeon.room_detectors_root = ensure_node("RoomDetectors")
	dungeon.room_lights_root = ensure_node("RoomLights")
	dungeon.enemies_root = ensure_node("Enemies")

func ensure_node(node_name: String) -> Node2D:
	if dungeon == null:
		return null

	var existing := dungeon.get_node_or_null(node_name) as Node2D
	if existing:
		return existing

	var node := Node2D.new()
	node.name = node_name
	dungeon.add_child(node)
	return node

func ensure_tile_map_layer(node_name: String) -> TileMapLayer:
	if dungeon == null:
		return null

	var existing := dungeon.get_node_or_null(node_name) as TileMapLayer
	if existing:
		return existing

	var created := TileMapLayer.new()
	created.name = node_name
	dungeon.add_child(created)
	return created

func clear_generated_content() -> void:
	if dungeon == null:
		return

	for parent in [
		dungeon.corridors_root,
		dungeon.rooms_root,
		dungeon.walls_root,
		dungeon.room_detectors_root,
		dungeon.room_lights_root,
		dungeon.enemies_root
	]:
		if parent == null:
			continue
		for child in parent.get_children():
			child.queue_free()
