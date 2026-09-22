extends Node
class_name ModuleBuildSystem

## ModuleBuildSystem: pops a build menu when an empty ModuleSlot is clicked,
## spends Industria via ResourceManager, and builds the chosen Module.
## Scene-instantiated per Main2d, like DoorTurnSystem/RoomPowerSystem.

var room_manager: RoomManager


func _ready() -> void:
	add_to_group("module_build_system")


func setup(p_room_manager: RoomManager) -> void:
	room_manager = p_room_manager
	if room_manager and not room_manager.slot_clicked.is_connected(_on_slot_clicked):
		room_manager.slot_clicked.connect(_on_slot_clicked)


func _on_slot_clicked(zone_id: String, slot: ModuleSlot) -> void:
	if not slot.is_empty():
		return

	var entries: Array = []
	for module_type in Module.CATALOG.keys():
		var cfg: Dictionary = Module.CATALOG[module_type]
		if cfg["slot"] == slot.slot_type:
			entries.append(module_type)
	if entries.is_empty():
		return

	var popup := PopupMenu.new()
	for module_type in entries:
		var cfg: Dictionary = Module.CATALOG[module_type]
		popup.add_item("%s (%d Industria)" % [cfg["label"], cfg["cost"]])
		popup.set_item_metadata(popup.item_count - 1, module_type)

	popup.id_pressed.connect(func(id: int): _on_item_selected(popup, id, zone_id, slot))
	popup.popup_hide.connect(popup.queue_free)

	get_tree().root.add_child(popup)
	var screen_pos: Vector2 = slot.get_viewport().get_screen_transform() * slot.global_position
	popup.popup(Rect2i(Vector2i(screen_pos), Vector2i.ZERO))


func _on_item_selected(popup: PopupMenu, id: int, zone_id: String, slot: ModuleSlot) -> void:
	var module_type: Module.ModuleType = popup.get_item_metadata(id)
	var cfg: Dictionary = Module.CATALOG[module_type]

	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager == null:
		return

	if not resource_manager.spend_resource("industry", int(cfg["cost"])):
		var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
		if text_mgr:
			text_mgr.spawn_text(slot.global_position, "Industria insuficiente", QuestPalette.GOLD_DARK)
		return

	slot.build(module_type)
	QuestLogger.info(QuestLogger.Category.MODULE, "Built '%s' in zone '%s'." % [cfg["label"], zone_id])
