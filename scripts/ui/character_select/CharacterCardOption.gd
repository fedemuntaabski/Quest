extends PanelContainer
class_name CharacterCardOption

## CharacterCardOption owns the visual structure for one selectable hero tile.
## Reused by CharacterSelection (single-player) and WaitingRoom (multiplayer lobby picker).

signal selected(character_id: String)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var select_button: Button = $MarginContainer/VBoxContainer/SelectButton

var _data: CharacterData = null
var _is_selected: bool = false
var _is_hovered: bool = false
var _is_taken: bool = false

const HOVER_COLOR: Color = QuestPalette.UI_PANEL_BORDER_HOVER
const NORMAL_COLOR: Color = QuestPalette.UI_PANEL_BORDER
const SELECTED_COLOR: Color = QuestPalette.UI_PANEL_BORDER_SELECTED
const TAKEN_COLOR: Color = QuestPalette.BLOOD


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	if select_button and not select_button.pressed.is_connected(_on_select_pressed):
		select_button.pressed.connect(_on_select_pressed)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	_apply_visual_state()


## Fills the tile with a hero's display data.
func setup(data: CharacterData) -> void:
	_data = data
	if data == null:
		return

	if name_label:
		name_label.text = data.display_name
	if icon_rect:
		icon_rect.visible = data.icon != null
		icon_rect.texture = data.icon
	if stats_label:
		stats_label.text = "HP %d · STR %d · MAG %d · DEX %d" % [data.base_hp, data.base_str, data.base_mag, data.base_dex]
	if description_label:
		description_label.text = data.description


func get_character_id() -> String:
	return _data.character_id if _data else ""


## Toggles the selected-highlight state (single-selection grids).
func set_selected(is_selected: bool) -> void:
	_is_selected = is_selected
	_apply_visual_state()


## Marks this hero as claimed by another player (multiplayer lobby only).
func set_taken(is_taken: bool, by_name: String = "") -> void:
	_is_taken = is_taken
	if select_button:
		select_button.disabled = is_taken
	if is_taken:
		_is_selected = false
		modulate.a = 0.5
		if description_label:
			description_label.text = "Elegido por %s" % by_name
	else:
		modulate.a = 1.0
		if description_label and _data:
			description_label.text = _data.description
	_apply_visual_state()


func _on_select_pressed() -> void:
	if _is_taken:
		return
	selected.emit(get_character_id())


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_visual_state()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_visual_state()


func _apply_visual_state() -> void:
	if _is_taken:
		add_theme_stylebox_override("panel", ThemeManager.build_reward_card_style(TAKEN_COLOR))
	elif _is_selected:
		add_theme_stylebox_override("panel", ThemeManager.build_reward_card_style(SELECTED_COLOR))
	elif _is_hovered:
		add_theme_stylebox_override("panel", ThemeManager.build_reward_card_style(HOVER_COLOR))
	else:
		add_theme_stylebox_override("panel", ThemeManager.build_reward_card_style(NORMAL_COLOR))
