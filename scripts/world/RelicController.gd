extends Node
class_name RelicController

## RelicController: gates Relic pickup (hero must physically be in
## "start_room") and kicks off the extraction phase on pickup.

const RELIC_ZONE_ID := "start_room"

var relic: Relic
var room_manager: RoomManager


func setup(p_relic: Relic, p_room_manager: RoomManager) -> void:
	relic = p_relic
	room_manager = p_room_manager
	if relic and not relic.relic_clicked.is_connected(_on_relic_clicked):
		relic.relic_clicked.connect(_on_relic_clicked)


func _on_relic_clicked(p_relic: Relic) -> void:
	var player := ManagerLocator.get_player()
	if player == null or player.current_zone_id != RELIC_ZONE_ID:
		QuestLogger.info(QuestLogger.Category.RELIC, "Relic pickup rejected: hero is not in '%s'." % RELIC_ZONE_ID)
		return

	player.pick_up_relic()
	p_relic.pick_up()

	var extraction := ManagerLocator.get_extraction_manager()
	if extraction:
		extraction.start_extraction()
