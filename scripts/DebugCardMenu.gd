extends CanvasLayer

@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton
@onready var card_container: CardContainer = $PanelContainer/VBoxContainer/CardContainer

func _ready() -> void:
	visible = false

	if close_button:
		close_button.pressed.connect(hide_menu)

func show_menu(container: CardContainer) -> void:
	visible = true

	# sincronizar datos
	card_container.equipped_cards = container.get_all_cards()
	card_container.cards_changed.emit(card_container.equipped_cards)

func hide_menu() -> void:
	visible = false