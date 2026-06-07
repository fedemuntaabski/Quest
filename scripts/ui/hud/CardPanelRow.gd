extends VBoxContainer
class_name CardPanelRow

@onready var content: HBoxContainer = $Content

@onready var left_column: VBoxContainer = $Content/LeftColumn
@onready var slot_label: Label = $Content/LeftColumn/SlotLabel
@onready var icon_rect: TextureRect = $Content/LeftColumn/IconRect

@onready var info_vbox: VBoxContainer = $Content/InfoVBox
@onready var name_label: Label = $Content/InfoVBox/NameHBox/NameLabel
@onready var cooldown_label: Label = $Content/InfoVBox/NameHBox/CooldownLabel
@onready var state_label: Label = $Content/InfoVBox/NameHBox/StateLabel
@onready var desc_label: Label = $Content/InfoVBox/DescLabel
@onready var stats_label: Label = $Content/InfoVBox/StatsLabel
@onready var swap_button: Button = $Content/InfoVBox/SwapButton

@onready var separator: HSeparator = $Separator


func setup_card(slot_num: int, data: CardDisplayData) -> void:
	visible = true

	_set_slot_number(slot_num, QuestPalette.PARCHMENT)

	icon_rect.texture = data.icon

	name_label.text = data.display_name

	cooldown_label.visible = data.cooldown_remaining > 0
	cooldown_label.text = "(CD: %d)" % data.cooldown_remaining

	state_label.text = "[READY]" if data.is_usable else "[BLOCKED]"
	state_label.add_theme_color_override(
		"font_color",
		QuestPalette.UI_TEXT_READY if data.is_usable else QuestPalette.UI_TEXT_BLOCKED
	)

	desc_label.text = data.description
	stats_label.text = CardPresentationAdapter.get_stats_summary(data)

	swap_button.visible = true
	swap_button.disabled = true

	_set_separator_alpha(0.30)


func setup_empty(slot_num: int) -> void:
	visible = true

	clear()

	_set_slot_number(slot_num, QuestPalette.UI_TEXT_MUTED)

	name_label.text = "Empty Slot"

	swap_button.visible = false

	_set_separator_alpha(0.20)


func clear() -> void:
	icon_rect.texture = null

	name_label.text = ""

	cooldown_label.visible = false
	cooldown_label.text = ""

	state_label.text = ""

	desc_label.text = ""

	stats_label.text = ""

	swap_button.visible = true
	swap_button.disabled = true


func _set_slot_number(slot_num: int, color: Color) -> void:
	slot_label.text = "[%d]" % slot_num
	slot_label.add_theme_color_override("font_color", color)


func _set_separator_alpha(alpha: float) -> void:
	separator.modulate = Color(
		QuestPalette.UI_TEXT_PRIMARY.r,
		QuestPalette.UI_TEXT_PRIMARY.g,
		QuestPalette.UI_TEXT_PRIMARY.b,
		alpha
	)