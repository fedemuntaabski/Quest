extends Node
class_name NexoController

## NexoController: gates Nexo pickup and kicks off the extraction phase.
## Session 7 rules: the exit room must be discovered first, and the hero must
## physically be in the map's start room (RoomManager.get_start_zone_id()).
## A valid click opens a confirmation dialog; "Recoger" picks it up.

const DIALOG_TEXT := "Al llevarte el Nexo las puertas se bloquean, las salas oscuras\nempiezan a generar oleadas y el héroe se mueve más lento.\n\nLlevalo hasta la salida para superar el piso."

var nexo: Nexo
var room_manager: RoomManager
var dialog: ConfirmationDialog


func setup(p_nexo: Nexo, p_room_manager: RoomManager) -> void:
	nexo = p_nexo
	room_manager = p_room_manager
	if nexo and not nexo.nexo_clicked.is_connected(_on_nexo_clicked):
		nexo.nexo_clicked.connect(_on_nexo_clicked)
	_build_dialog()


## Empty string = pickup allowed; otherwise the reason, shown to the player.
func get_block_reason() -> String:
	if not room_manager.is_zone_revealed(room_manager.get_exit_zone_id()):
		return "Descubrí la salida antes de llevarte el Nexo"
	var player := ManagerLocator.get_player()
	if player == null or player.current_zone_id != room_manager.get_start_zone_id():
		return "Acercate al Nexo para recogerlo"
	return ""


func _on_nexo_clicked(p_nexo: Nexo) -> void:
	var reason := get_block_reason()
	if reason != "":
		QuestLogger.info(QuestLogger.Category.NEXO, "Nexo pickup rejected: %s." % reason)
		var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
		if text_mgr:
			text_mgr.spawn_text(p_nexo.global_position, reason, QuestPalette.GOLD_DARK)
		return
	dialog.popup_centered()


## Dialog "Recoger": conditions are re-checked (the hero may have moved).
func confirm_pickup() -> void:
	if nexo == null or get_block_reason() != "":
		return
	var player := ManagerLocator.get_player()
	player.pick_up_nexo()
	nexo.pick_up()

	var extraction := ManagerLocator.get_extraction_manager()
	if extraction:
		extraction.start_extraction()


func _build_dialog() -> void:
	if dialog:
		return
	dialog = ConfirmationDialog.new()
	dialog.name = "NexoDialog"
	dialog.title = "El Nexo"
	dialog.dialog_text = DIALOG_TEXT
	dialog.ok_button_text = "Recoger"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(confirm_pickup)
	add_child(dialog)
