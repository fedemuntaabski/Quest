extends Node
class_name RelicController

## RelicController: gates Relic pickup and kicks off the extraction phase.
## Session 7 rules: the exit room must be discovered first, and the hero must
## physically be in the map's start room (RoomManager.get_start_zone_id()).
## A valid click opens a confirmation dialog; "Recoger" picks it up.
## Bucle-7: a Relic dropped by a fallen carrier (Relic.drop_at) is picked up by any
## living hero standing in that zone, with no dialog and no new extraction.

const DIALOG_TEXT := "Al llevarte la Reliquia las puertas se bloquean, las salas oscuras\nempiezan a generar oleadas y el héroe se mueve más lento.\n\nLlevala hasta la salida para superar el piso."

var relic: Relic
var room_manager: RoomManager
var dialog: ConfirmationDialog


func setup(p_relic: Relic, p_room_manager: RoomManager) -> void:
	relic = p_relic
	room_manager = p_room_manager
	if relic and not relic.relic_clicked.is_connected(_on_relic_clicked):
		relic.relic_clicked.connect(_on_relic_clicked)
	_build_dialog()


## Empty string = pickup allowed; otherwise the reason, shown to the player.
## coop-12: `hero` = who picks it up (default: the local primary hero).
func get_block_reason(hero: Player = null) -> String:
	if relic.is_carried():
		return "La Reliquia ya la lleva un héroe"
	var dropped := relic.is_dropped()
	# First pickup needs the exit discovered; a dropped Relic is already mid-extraction.
	if not dropped and not room_manager.is_zone_revealed(room_manager.get_exit_zone_id()):
		return "Descubrí la salida antes de llevarte la Reliquia"
	var player := hero if hero else ManagerLocator.get_player()
	var relic_zone := relic.drop_zone_id if dropped else room_manager.get_start_zone_id()
	if player == null or not player.stats.is_alive() or player.current_zone_id != relic_zone:
		return "Acercate a la Reliquia para recogerla"
	return ""


func _on_relic_clicked(p_relic: Relic) -> void:
	var reason := get_block_reason()
	if reason != "":
		QuestLogger.info(QuestLogger.Category.RELIC, "Relic pickup rejected: %s." % reason)
		var hud := ManagerLocator.get_hud()
		if hud:
			hud.show_refusal(reason)
		return
	if relic.is_dropped():
		_request_pickup()  # nothing new to warn about: the extraction is already on
		return
	dialog.popup_centered()


## coop-12: the local primary hero asks to carry it (the host checks and does it).
func _request_pickup() -> void:
	var player := ManagerLocator.get_player()
	if player:
		ManagerLocator.get_net_commands().request("pickup_relic", {"hero": player.stats.hero_id})


## Dialog "Recoger" (or a click on a dropped Relic): conditions are re-checked (the hero may have moved).
func confirm_pickup(hero: Player = null) -> void:
	if relic == null or get_block_reason(hero) != "":
		return
	var player := hero if hero else ManagerLocator.get_player()
	player.pick_up_relic()
	relic.pick_up()
	var audio := ManagerLocator.get_audio()
	if audio:
		audio.play_sfx(&"relic")

	var extraction := ManagerLocator.get_extraction_manager()
	if extraction:
		extraction.start_extraction()


func _build_dialog() -> void:
	if dialog:
		return
	dialog = ConfirmationDialog.new()
	dialog.name = "RelicDialog"
	dialog.title = "La Reliquia"
	dialog.dialog_text = DIALOG_TEXT
	dialog.ok_button_text = "Recoger"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(_request_pickup)
	add_child(dialog)
