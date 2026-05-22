extends RefCounted
class_name DungeonRuntimeSetup

func ensure_runtime_nodes(generator: DungeonGenerator) -> void:
	if generator == null:
		return

	# Helpers are RefCounted — create and setup without attaching to scene tree
	if generator.scene_helper == null:
		generator.scene_helper = DungeonSceneHelper.new()
		generator.scene_helper.setup(generator)

	if generator.layout_generator == null:
		generator.layout_generator = DungeonLayoutGenerator.new()
		generator.layout_generator.setup(generator)

	if generator.room_manager == null:
		generator.room_manager = DungeonRoomManager.new()
		generator.room_manager.setup(generator)

	if generator.wall_manager == null:
		generator.wall_manager = DungeonWallManager.new()
		generator.wall_manager.setup(generator)

	_ensure_managers(generator)

	if generator.room_factory == null:
		generator.room_factory = DungeonRoomFactory.new()
		generator.room_factory.setup(generator, generator.room_system)

	_ensure_scene_roots(generator)

func _ensure_managers(generator: DungeonGenerator) -> void:
	if generator.room_system == null:
		generator.room_system = RoomSystem.new()
		generator.room_system.name = "RoomSystem"
		generator.add_child(generator.room_system)

	generator.room_system.setup(generator)
	var room_changed_cb := Callable(generator, "_set_active_room").bind(true)
	if not generator.room_system.room_changed.is_connected(room_changed_cb):
		generator.room_system.room_changed.connect(room_changed_cb)

	if generator.room_camera_controller == null:
		generator.room_camera_controller = RoomCameraController.new()
		generator.room_camera_controller.name = "RoomCameraController"
		generator.add_child(generator.room_camera_controller)

	generator.room_camera_controller.setup(generator)

func _ensure_scene_roots(generator: DungeonGenerator) -> void:
	if generator.scene_helper:
		generator.scene_helper.ensure_scene_roots()
