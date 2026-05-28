extends RefCounted
class_name ModularRoomAssembler

const TUTORIAL_ROOM_SCENE := preload("res://scenes/sala_tutorial.tscn")
const BOSS_ROOM_SCENE := preload("res://scenes/sala_boss.tscn")
const NORMAL_ROOM_SCENES := [
	preload("res://scenes/sala_1.tscn"),
	preload("res://scenes/sala_1_rotada.tscn"),
	preload("res://scenes/sala_2.tscn"),
	preload("res://scenes/sala_2_rotada.tscn"),
	preload("res://scenes/sala_3.tscn"),
	preload("res://scenes/sala_3_rotada.tscn"),
	preload("res://scenes/sala_4.tscn"),
	preload("res://scenes/sala_4_rotada.tscn")
]

var dungeon: DungeonGenerator = null
var room_prefab_adapter: RoomPrefabAdapter = null


func setup(p_dungeon: DungeonGenerator, p_room_prefab_adapter: RoomPrefabAdapter) -> void:
	dungeon = p_dungeon
	room_prefab_adapter = p_room_prefab_adapter


func build_room_instance(room_info: Dictionary, rooms_root: Node2D = null) -> Dictionary:
	var template := _resolve_room_template(room_info)
	if template == null or room_prefab_adapter == null:
		return {}

	var room_rect: Rect2i = room_info.get("rect", Rect2i())
	var room_origin_world := _room_origin_world(room_rect)
	var rotation_degrees := int(room_info.get("rotation_degrees", 0))
	var room_root := room_prefab_adapter.create_prefab_room_instance(template, rooms_root, room_origin_world, rotation_degrees)
	if room_root == null:
		return {}

	var snapshot := room_prefab_adapter.inspect_template(template)
	if snapshot.is_empty():
		snapshot = room_prefab_adapter.inspect_scene(template.room_scene)

	var local_floor_cells: Array = snapshot.get("local_floor_cells", room_info.get("local_floor_cells", []))
	var runtime_floor_cells := room_prefab_adapter.build_world_floor_cells_from_local_cells(
		local_floor_cells,
		room_rect.position,
		room_rect.size,
		rotation_degrees
	)

	var marker_refs := room_prefab_adapter.resolve_marker_references(room_root)

	return {
		"visual_root": room_root,
		"template": template,
		"snapshot": snapshot,
		"connectors": snapshot.get("connectors", []),
		"spawn_markers": snapshot.get("spawn_markers", []),
		"marker_refs": marker_refs,
		"local_floor_cells": local_floor_cells,
		"floor_cells": runtime_floor_cells,
		"room_role": _room_role_for_info(room_info),
		"prefab_scene_path": template.room_scene.resource_path if template.room_scene else "",
		"prefab_rotation_degrees": rotation_degrees
	}


func _resolve_room_template(room_info: Dictionary) -> RoomTemplateData:
	var room_role := _room_role_for_info(room_info)
	match room_role:
		"tutorial":
			return _build_template(TUTORIAL_ROOM_SCENE, &"tutorial_room", &"tutorial", true)
		"boss":
			return _build_template(BOSS_ROOM_SCENE, &"boss_room", &"boss", true)
		_:
			return _pick_normal_room_template(room_info)


func _pick_normal_room_template(room_info: Dictionary) -> RoomTemplateData:
	if NORMAL_ROOM_SCENES.is_empty():
		return null

	var room_id := int(room_info.get("id", -1))
	var scene_index := randi() % NORMAL_ROOM_SCENES.size()
	if room_id >= 0:
		scene_index = abs(room_id) % NORMAL_ROOM_SCENES.size()

	return _build_template(NORMAL_ROOM_SCENES[scene_index], &"normal_room", &"normal", false)


func _build_template(scene: PackedScene, room_type: StringName, spawn_profile: StringName, is_boss_room: bool) -> RoomTemplateData:
	if scene == null:
		return null

	var template := RoomTemplateData.new()
	template.room_scene = scene
	template.room_type = room_type
	template.spawn_profile = spawn_profile
	template.is_boss_room = is_boss_room
	template.weight = 1.0
	return template


func _room_role_for_info(room_info: Dictionary) -> String:
	if dungeon == null:
		return "normal"

	var room_id := int(room_info.get("id", -1))
	if room_id == 0:
		return "tutorial"
	if room_id == dungeon.room_count - 1:
		return "boss"
	return "normal"


func _room_origin_world(room_rect: Rect2i) -> Vector2:
	if dungeon == null:
		return Vector2.ZERO
	return dungeon.grid_origin + Vector2(room_rect.position) * dungeon.tile_size