extends HBoxContainer
class_name CardPanelRow

## CardPanelRow owns one entry in the HUD card list.
## CardPanelUI populates it with either a card record or an empty-slot presentation.

@onready var slot_label: Label = $SlotLabel
@onready var icon_rect: TextureRect = $IconRect
@onready var info_vbox: VBoxContainer = $InfoVBox
@onready var name_hbox: HBoxContainer = $InfoVBox/NameHBox
@onready var name_label: Label = $InfoVBox/NameHBox/NameLabel
@onready var cooldown_label: Label = $InfoVBox/NameHBox/CooldownLabel
@onready var state_label: Label = $InfoVBox/NameHBox/StateLabel
@onready var desc_label: Label = $InfoVBox/DescLabel
@onready var stats_label: Label = $InfoVBox/StatsLabel
@onready var swap_button: Button = $InfoVBox/SwapButton
@onready var separator: HSeparator = $Separator

func setup_card(slot_num: int, data: CardDisplayData) -> void:
	visible = true
	if slot_label:
		slot_label.text = "[%d]" % slot_num
		slot_label.add_theme_color_override("font_color", QuestPalette.PARCHMENT)
	if icon_rect:
		icon_rect.texture = data.icon
	if name_label:
		name_label.text = data.display_name
	if cooldown_label:
		cooldown_label.visible = data.cooldown_remaining > 0
		cooldown_label.text = "(CD: %d)" % data.cooldown_remaining
	if state_label:
		state_label.text = "[READY]" if data.is_usable else "[BLOCKED]"
		state_label.add_theme_color_override("font_color", QuestPalette.UI_TEXT_READY if data.is_usable else QuestPalette.UI_TEXT_BLOCKED)
	if desc_label:
		desc_label.text = data.description
	if stats_label:
		stats_label.text = CardPresentationAdapter.get_stats_summary(data)
	if swap_button:
		swap_button.disabled = true
	if separator:
		separator.modulate = Color(QuestPalette.UI_TEXT_PRIMARY.r, QuestPalette.UI_TEXT_PRIMARY.g, QuestPalette.UI_TEXT_PRIMARY.b, 0.30)

func setup_empty(slot_num: int) -> void:
	visible = true
	if slot_label:
		slot_label.text = "[%d]" % slot_num
		slot_label.add_theme_color_override("font_color", QuestPalette.UI_TEXT_MUTED)
	if icon_rect:
		icon_rect.texture = null
	if name_label:
		name_label.text = "Empty Slot"
	if cooldown_label:
		cooldown_label.visible = false
	if state_label:
		state_label.text = ""
	if desc_label:
		desc_label.text = ""
	if stats_label:
		stats_label.text = ""
	if swap_button:
		swap_button.visible = false
	if separator:
		separator.modulate = Color(QuestPalette.UI_TEXT_PRIMARY.r, QuestPalette.UI_TEXT_PRIMARY.g, QuestPalette.UI_TEXT_PRIMARY.b, 0.20)
