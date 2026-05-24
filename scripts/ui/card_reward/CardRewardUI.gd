extends CanvasLayer
class_name CardRewardUI

## CardRewardUI is a presentation layer for reward selection.
## It owns visual feedback and animation.
## It delegates workflow state to RewardFlowState.

signal card_selected(card: CardData)
signal reward_skipped
signal card_replace_selected(card: CardData, slot_index: int)

const RewardCardOptionScene := preload("res://scenes/RewardCardOption.tscn")

@onready var panel: Panel = $CenterContainer/RewardPanel
@onready var cards_container: HBoxContainer = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/CardsScroll/CardsContainer
@onready var footer_container: CenterContainer = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/FooterContainer
@onready var title_label: Label = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/TitleLabel

var _reward_cards: Array[CardData] = []
var _is_active: bool = false  # Local UI visibility state
var _selected_card_button: RewardCardOption = null  # Local visual feedback tracking
var _flow_state: RewardFlowState = null  # Owns workflow state

# Style constants for visual feedback
const HOVER_COLOR: Color = QuestPalette.UI_PANEL_BORDER_HOVER
const NORMAL_COLOR: Color = QuestPalette.UI_PANEL_BORDER
const SELECTED_COLOR: Color = QuestPalette.UI_PANEL_BORDER_SELECTED
const CARD_BUTTON_WIDTH: float = 220.0
const CARD_BUTTON_HEIGHT: float = 280.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_is_active = false
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create workflow state handler
	_flow_state = RewardFlowState.new()
	add_child(_flow_state)
	_flow_state.reward_flow_completed.connect(_on_reward_flow_completed)

func show_reward(cards: Array, requires_replace: bool = false, equipped_slots: Array = []) -> void:
	if cards.is_empty():
		return
	
	# Initialize workflow state
	_flow_state.start_reward_session(cards, requires_replace, equipped_slots)
	
	# Store cards for presentation
	_reward_cards.clear()
	_reward_cards.assign(cards)
	
	# Clear UI and prepare for animation
	_clear_cards_container()
	_create_card_buttons()
	_add_skip_button()
	
	if panel:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.98, 0.98)
	visible = true
	_is_active = true
	title_label.text = "Choose a Card Reward" if not requires_replace else "Choose a Card (then replace a slot)"
	
	_play_show_animation()

func hide_reward() -> void:
	if not visible:
		return
	_play_hide_animation()

func _finalize_hide() -> void:
	visible = false
	_is_active = false
	_selected_card_button = null
	_clear_cards_container()
	# Workflow state is managed by RewardFlowState; UI layer only manages visibility

func _clear_cards_container() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	if footer_container:
		for child in footer_container.get_children():
			child.queue_free()

func _create_card_buttons() -> void:
	for card in _reward_cards:
		if card == null:
			continue
		var card_button := _create_card_button(card)
		if card_button == null:
			continue
		cards_container.add_child(card_button)
		card_button.setup(card)

func _add_skip_button() -> void:
	var skip_button := Button.new()
	skip_button.text = "Skip Reward"
	skip_button.custom_minimum_size = Vector2(140, 32)
	skip_button.pressed.connect(_on_skip_pressed)
	if footer_container:
		footer_container.add_child(skip_button)
	else:
		cards_container.add_child(skip_button)

func _create_card_button(_card: CardData) -> RewardCardOption:
	var option := RewardCardOptionScene.instantiate() as RewardCardOption
	if option == null:
		return null
	if not option.selected.is_connected(_on_card_option_selected):
		option.selected.connect(_on_card_option_selected)
	return option

func _on_card_option_selected(option: RewardCardOption) -> void:
	if option == null:
		return
	_on_card_selected(option.get_card(), option)

func _on_card_selected(card: CardData, button: RewardCardOption = null) -> void:
	if not _is_active:
		return
	
	# Visual feedback: highlight selected card
	if _selected_card_button != null and _selected_card_button != button:
		_selected_card_button.set_selected(false)
	_selected_card_button = button
	if button:
		button.set_selected(true)
	
	# Delegate workflow state to RewardFlowState
	_flow_state.select_card(card)
	
	# If replacement is required, RewardFlowState transitions to SLOT_PENDING and
	# this UI switches into its slot-selection presentation path.
	if _flow_state.is_awaiting_slot_selection():
		_queue_replace_selection()
	elif _flow_state.is_complete():
		# Direct completion (no replacement needed)
		hide_reward()
		card_selected.emit(card)

func _show_replace_selection() -> void:
	# Clear and transition to slot selection
	_clear_cards_container()
	
	# Animate transition with cross-fade effect
	if panel:
		var tw = create_tween()
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(panel, "modulate:a", 0.3, 0.1)
		tw.tween_callback(func(): _refresh_slot_selection())
		tw.tween_property(panel, "modulate:a", 1.0, 0.1)
	else:
		_refresh_slot_selection()

## Plays the entrance animation for the reward panel.
func _play_show_animation() -> void:
	if panel == null:
		return
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2(1, 1), 0.15)

## Plays the exit animation and finalizes visibility once it completes.
func _play_hide_animation() -> void:
	if panel == null:
		_finalize_hide()
		return
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): _finalize_hide())

## Defers the slot-selection swap so the reward panel can settle before the next UI state.
func _queue_replace_selection() -> void:
	await get_tree().create_timer(0.15).timeout
	_show_replace_selection()

func _refresh_slot_selection() -> void:
	title_label.text = "Hotbar Full - Select Slot to Replace"
	
	# Create header for clarity
	var header := Label.new()
	header.text = "Which card will you replace?"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", QuestPalette.UI_TEXT_PRIMARY)
	header.custom_minimum_size = Vector2(0, 30)
	cards_container.add_child(header)
	
	# Add separator for visual clarity
	var separator := Control.new()
	separator.custom_minimum_size = Vector2(0, 4)
	cards_container.add_child(separator)
	
	# Get replacement slots from workflow state
	var replace_slots: Array[Dictionary] = _flow_state.get_replacement_slots()
	
	# Create slot buttons with better layout
	for slot in replace_slots:
		var slot_index: int = int(slot.get("slot_index", -1))
		var slot_name: String = str(slot.get("name", "Unknown"))
		var icon_tex: Texture2D = slot.get("icon", null)
		
		# Horizontal box for each slot
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(0, 48)
		h.add_theme_constant_override("separation", 16)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Icon with background
		var icon_bg := PanelContainer.new()
		icon_bg.custom_minimum_size = Vector2(48, 48)
		icon_bg.add_theme_stylebox_override("panel", _build_slot_icon_style())
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if icon_tex:
			icon.texture = icon_tex
		icon_bg.add_child(icon)
		h.add_child(icon_bg)
		
		# Slot label
		var lbl := Label.new()
		lbl.text = "Slot %d" % [slot_index + 1]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.custom_minimum_size = Vector2(80, 0)
		h.add_child(lbl)
		
		# Card name being replaced
		var card_name := Label.new()
		card_name.text = "[%s]" % slot_name
		card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_name.add_theme_font_size_override("font_size", 13)
		card_name.add_theme_color_override("font_color", QuestPalette.UI_TEXT_SECONDARY)
		card_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(card_name)
		
		# Replace button
		var btn := Button.new()
		btn.text = "Replace"
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_on_replace_slot_selected.bind(slot_index))
		h.add_child(btn)
		
		cards_container.add_child(h)
	
	_add_skip_button()

func _build_slot_icon_style() -> StyleBoxFlat:
	return ThemeManager.build_slot_icon_style()

func _on_replace_slot_selected(slot_index: int) -> void:
	if not _is_active:
		return
	
	# Delegate to RewardFlowState to validate and complete the workflow
	_flow_state.select_replacement_slot(slot_index)

func _on_skip_pressed() -> void:
	if not _is_active:
		return
	
	# Skip through workflow state
	_flow_state.skip_reward()
	hide_reward()
	reward_skipped.emit()
func _on_reward_flow_completed(selected_card: CardData, slot_index: int) -> void:
	# Forward the completed workflow event to upstream handlers
	if slot_index >= 0:
		card_replace_selected.emit(selected_card, slot_index)
	else:
		card_selected.emit(selected_card)
