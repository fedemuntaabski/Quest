extends Node
class_name ModuleBuildSystem

## ModuleBuildSystem: routes an empty BuildingSlot click to the HUD's BuildingMenu,
## which owns the purchase (Industria spend + slot.build()).
## Scene-instantiated per Main2d, like DoorTurnSystem/RoomPowerSystem.

var room_manager: RoomManager


func _ready() -> void:
	add_to_group("module_build_system")


func setup(p_room_manager: RoomManager) -> void:
	room_manager = p_room_manager
	if room_manager and not room_manager.slot_clicked.is_connected(_on_slot_clicked):
		room_manager.slot_clicked.connect(_on_slot_clicked)


func _on_slot_clicked(zone_id: String, slot: BuildingSlot) -> void:
	if not slot.is_empty():
		return

	var hud := get_tree().get_first_node_in_group("hud") as HUDController
	if hud == null:
		QuestLogger.warn(QuestLogger.Category.UI, "ModuleBuildSystem: HUD not found; cannot open build menu for zone '%s'." % zone_id)
		return
	hud.open_building_menu(slot)
