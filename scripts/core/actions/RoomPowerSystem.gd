extends Node
class_name RoomPowerSystem

## RoomPowerSystem: observes rooms lit via RoomZone.try_power_up() (which owns
## the Dust transaction) and re-broadcasts `room_energized`. Scene-instantiated
## per Main2d, like DoorTurnSystem — not an autoload.

signal room_energized(zone_id: String)

var room_manager: RoomManager


func _ready() -> void:
	add_to_group("room_power_system")


func setup(p_room_manager: RoomManager) -> void:
	room_manager = p_room_manager
	if room_manager and not room_manager.room_powered.is_connected(_on_room_powered):
		room_manager.room_powered.connect(_on_room_powered)


func _on_room_powered(zone_id: String) -> void:
	room_energized.emit(zone_id)
	QuestLogger.info(QuestLogger.Category.ROOM, "Zone '%s' energized for %d dust." % [zone_id, RoomZone.POWER_COST])
