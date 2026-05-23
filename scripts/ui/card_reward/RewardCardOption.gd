extends PanelContainer
class_name RewardCardOption

## RewardCardOption owns the visual structure for one reward card tile.
## CardRewardUI feeds it data and listens for selection, but the tile owns hover and selected feedback.

signal selected(option: RewardCardOption)

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var category_label: Label = $MarginContainer/VBoxContainer/CategoryLabel
@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/Icon
@onready var stats_label: Label = $MarginContainer/VBoxContainer/StatsLabel
@onready var effects_label: Label = $MarginContainer/VBoxContainer/EffectsScroll/EffectsLabel
@onready var select_button: Button = $MarginContainer/VBoxContainer/SelectButton

var _card: CardData = null
var _is_selected: bool = false
var _is_hovered: bool = false

const HOVER_COLOR: Color = Color(0.4, 0.5, 0.7, 1.0)
const NORMAL_COLOR: Color = Color(0.3, 0.32, 0.38, 1.0)
const SELECTED_COLOR: Color = Color(0.6, 0.8, 1.0, 1.0)

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

## Fills the tile with the card's display data.
func setup(card: CardData) -> void:
	_card = card
	if card == null:
		return

	var display_data: CardDisplayData = CardPresentationAdapter.create_display_data(card)
	if name_label:
		name_label.text = display_data.display_name
	if category_label:
		category_label.text = "[%s]" % str(display_data.category).to_upper()
		category_label.add_theme_color_override("font_color", CardPresentationAdapter.get_category_color(display_data.category))
	if icon_rect:
		icon_rect.texture = display_data.icon
	if stats_label:
		stats_label.text = CardPresentationAdapter.get_stats_summary(display_data)
	if effects_label:
		effects_label.text = CardPresentationAdapter.get_effects_summary(card)

## Returns the card assigned to this option.
func get_card() -> CardData:
	return _card

## Allows the parent scene to keep the selected state in sync.
func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_visual_state()

func _on_select_pressed() -> void:
	selected.emit(self)

func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_visual_state()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_visual_state()

func _apply_visual_state() -> void:
	if _is_selected:
		add_theme_stylebox_override("panel", _build_card_style(SELECTED_COLOR))
	elif _is_hovered:
		add_theme_stylebox_override("panel", _build_card_style(HOVER_COLOR))
	else:
		add_theme_stylebox_override("panel", _build_card_style(NORMAL_COLOR))

func _build_card_style(border_color: Color = NORMAL_COLOR) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style
