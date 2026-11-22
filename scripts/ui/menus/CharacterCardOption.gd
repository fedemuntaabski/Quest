extends PanelContainer
class_name CharacterCardOption

## CharacterCardOption owns the visual structure for one selectable hero tile.
## Used by WaitingRoom (multiplayer lobby picker).

signal selected(character_id: String)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var portrait_rect: TextureRect = $MarginContainer/VBoxContainer/PortraitRect
@onready var role_label: Label = $MarginContainer/VBoxContainer/RoleLabel
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var ability_label: Label = $MarginContainer/VBoxContainer/AbilityLabel
@onready var select_button: Button = $MarginContainer/VBoxContainer/SelectButton

var _data: CharacterData = null
var _is_selected: bool = false
var _is_hovered: bool = false
var _is_taken: bool = false



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_apply_text_style()
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
	if portrait_rect:
		portrait_rect.visible = data.portrait != null
		portrait_rect.texture = data.portrait
	if role_label:
		role_label.text = data.description
	if stats_label:
		stats_label.text = "Vida: %d" % data.base_hp
	if ability_label:
		ability_label.text = "%s\n%s" % [data.passive_ability_name, data.passive_ability_desc]


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
		if role_label:
			role_label.text = "Elegido por %s" % by_name
	else:
		modulate.a = 1.0
		if role_label and _data:
			role_label.text = _data.description
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


## menu-33: crypt-stone tile (UiStyles.build_card_style), parchment/gold text.
func _apply_text_style() -> void:
	if name_label:
		UiStyles.style_menu_title(name_label, 26)
	for label: Label in [role_label, ability_label]:
		if label:
			UiStyles.style_menu_text(label, 14, QuestPalette.PARCHMENT)
	if stats_label:
		UiStyles.style_menu_text(stats_label, 14, QuestPalette.RELIC_GOLD)
	if select_button:
		UiStyles.style_plaque_button(select_button, false, 18, false)


func _apply_visual_state() -> void:
	if _is_taken:
		add_theme_stylebox_override("panel", UiStyles.build_card_style("taken"))
	elif _is_selected:
		add_theme_stylebox_override("panel", UiStyles.build_card_style("picked"))
	elif _is_hovered:
		add_theme_stylebox_override("panel", UiStyles.build_card_style("hot"))
	else:
		add_theme_stylebox_override("panel", UiStyles.build_card_style("normal"))
