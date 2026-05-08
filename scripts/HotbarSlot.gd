extends PanelContainer
class_name HotbarSlot

signal slot_pressed(index: int)

@export var slot_index: int = 0

@onready var icon: TextureRect = $VBox/Icon
@onready var name_label: Label = $VBox/Name
@onready var cooldown_label: Label = $VBox/Cooldown

var _card_data: Dictionary = {}
var _is_selected: bool = false

func _ready() -> void:
	_update_ui()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_pressed.emit(slot_index)

func set_card(data: Dictionary) -> void:
	_card_data = data if data != null else {}
	_update_ui()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	self_modulate = Color(1, 1, 1, 1) if selected else Color(0.8, 0.8, 0.8, 1)

func set_cooldown(turns_left: int) -> void:
	if turns_left > 0:
		cooldown_label.text = "CD: %d" % turns_left
		cooldown_label.visible = true
	else:
		cooldown_label.text = ""
		cooldown_label.visible = false

func _update_ui() -> void:
	if name_label:
		name_label.text = _card_data.get("name", "-")

	if icon:
		var tex: Texture2D = _card_data.get("icon", null)
		icon.texture = tex

	set_cooldown(int(_card_data.get("cooldown_remaining", 0)))
