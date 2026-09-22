extends Node
class_name RoomPowerSystem

## RoomPowerSystem: spends Dust to power a revealed room, unlocking its
## module build slots (see RoomZone.set_powered / Module system). Scene-
## instantiated per Main2d, like DoorTurnSystem — not an autoload.

const ENERGIZE_COST := 10

signal room_energized(zone_id: String)

var room_manager: RoomManager


func _ready() -> void:
	add_to_group("room_power_system")


func setup(p_room_manager: RoomManager) -> void:
	room_manager = p_room_manager
	if room_manager and not room_manager.energize_requested.is_connected(_on_energize_requested):
		room_manager.energize_requested.connect(_on_energize_requested)


func _on_energize_requested(zone_id: String) -> void:
	if room_manager == null:
		return
	if not room_manager.is_zone_revealed(zone_id) or room_manager.is_zone_powered(zone_id):
		return

	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager == null:
		return

	if not resource_manager.spend_resource("dust", ENERGIZE_COST):
		var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
		if text_mgr:
			text_mgr.spawn_text(room_manager.get_center(zone_id), "Polvo insuficiente", QuestPalette.GOLD_DARK)
		return

	room_manager.set_zone_powered(zone_id, true)
	room_energized.emit(zone_id)
	QuestLogger.info(QuestLogger.Category.ROOM, "Zone '%s' energized for %d dust." % [zone_id, ENERGIZE_COST])
