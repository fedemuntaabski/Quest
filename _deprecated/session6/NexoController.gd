extends Node
class_name NexoController

## NexoController: gates Nexo pickup (hero must physically be in the map's
## start room, RoomManager.get_start_zone_id()) and kicks off the extraction
## phase on pickup.

var nexo: Nexo
var room_manager: RoomManager


func setup(p_nexo: Nexo, p_room_manager: RoomManager) -> void:
	nexo = p_nexo
	room_manager = p_room_manager
	if nexo and not nexo.nexo_clicked.is_connected(_on_nexo_clicked):
		nexo.nexo_clicked.connect(_on_nexo_clicked)


func _on_nexo_clicked(p_nexo: Nexo) -> void:
	var player := ManagerLocator.get_player()
	var nexo_zone_id := room_manager.get_start_zone_id()
	if player == null or player.current_zone_id != nexo_zone_id:
		QuestLogger.info(QuestLogger.Category.NEXO, "Nexo pickup rejected: hero is not in '%s'." % nexo_zone_id)
		return

	player.pick_up_nexo()
	p_nexo.pick_up()

	var extraction := ManagerLocator.get_extraction_manager()
	if extraction:
		extraction.start_extraction()
