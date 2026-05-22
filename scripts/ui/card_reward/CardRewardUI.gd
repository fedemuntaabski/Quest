extends CanvasLayer
class_name CardRewardUI

## CardRewardUI is a presentation layer for reward selection.
## It owns visual feedback and animation.
## It delegates workflow state to RewardFlowState.

signal card_selected(card: CardData)
signal reward_skipped
signal card_replace_selected(card: CardData, slot_index: int)

@onready var panel: Panel = $CenterContainer/RewardPanel
@onready var cards_container: HBoxContainer = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/CardsScroll/CardsContainer
@onready var footer_container: CenterContainer = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/FooterContainer
@onready var title_label: Label = $CenterContainer/RewardPanel/MarginContainer/VBoxContainer/TitleLabel

var _reward_cards: Array[CardData] = []
var _card_nodes: Array = []
var _is_active: bool = false  # Local UI visibility state
var _selected_card_button: Control = null  # Local visual feedback tracking
var _flow_state: RewardFlowState = null  # Owns workflow state

const CARD_REWARD_COUNT: int = 3

# Style constants for visual feedback
const HOVER_COLOR: Color = Color(0.4, 0.5, 0.7, 1.0)
const NORMAL_COLOR: Color = Color(0.3, 0.32, 0.38, 1.0)
const SELECTED_COLOR: Color = Color(0.6, 0.8, 1.0, 1.0)
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
	_flow_state.state_changed.connect(_on_flow_state_changed)
	_flow_state.reward_flow_completed.connect(_on_reward_flow_completed)

func show_reward(cards: Array, requires_replace: bool = false, equipped_slots: Array = []) -> void:
	if cards.is_empty():
		return
	
	# Initialize workflow state
	_flow_state.start_reward_session(cards, requires_replace, equipped_slots)
	
	# Store cards for presentation
	_reward_cards.clear()
	_reward_cards.assign(cards)
	_card_nodes.clear()
	
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
	
	# Entrance animation
	if panel:
		var tw = create_tween()
		tw.tween_property(panel, "modulate:a", 1.0, 0.18)
		tw.tween_property(panel, "scale", Vector2(1, 1), 0.15)

func hide_reward() -> void:
	if not visible:
		return
	# Exit animation, then finalize hide
	if panel:
		var tw = create_tween()
		tw.tween_property(panel, "modulate:a", 0.0, 0.12)
		tw.tween_callback(func(): _finalize_hide())
	else:
		_finalize_hide()

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
		cards_container.add_child(card_button)

func _add_skip_button() -> void:
	var skip_button := Button.new()
	skip_button.text = "Skip Reward"
	skip_button.custom_minimum_size = Vector2(140, 32)
	skip_button.pressed.connect(_on_skip_pressed)
	if footer_container:
		footer_container.add_child(skip_button)
	else:
		cards_container.add_child(skip_button)

func _create_card_button(card: CardData) -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(CARD_BUTTON_WIDTH, CARD_BUTTON_HEIGHT)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.focus_mode = Control.FOCUS_NONE
	
	# Store card reference for later access
	container.set_meta("card_data", card)
	
	# Setup hover/selection feedback
	var hover_style := _build_card_style(NORMAL_COLOR)
	container.add_theme_stylebox_override("panel", hover_style)
	
	# Mouse enter/exit for hover effect
	container.mouse_entered.connect(func(): _on_card_button_hover_enter(container))
	container.mouse_exited.connect(func(): _on_card_button_hover_exit(container))
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Title - larger, bold appearance
	var display_data := CardPresentationAdapter.create_display_data(card)
	var view := {
		"display_name": display_data.display_name,
		"description": display_data.description,
		"icon": display_data.icon,
		"category": display_data.category,
		"stats_summary": CardPresentationAdapter.get_stats_summary(display_data),
		"effects_summary": CardPresentationAdapter.get_effects_summary(card)
	}
	var name_label := Label.new()
	name_label.text = view.get("display_name")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.max_lines_visible = 2
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(name_label)
	
	# Category badge
	var category_label := Label.new()
	category_label.text = "[%s]" % str(view.get("category", "")).to_upper()
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category_label.add_theme_font_size_override("font_size", 11)
	var category_color := _get_category_color(card.category)
	category_label.add_theme_color_override("font_color", category_color)
	vbox.add_child(category_label)
	
	# Icon with proper sizing
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(188, 100)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if view.get("icon"):
		icon.texture = view.get("icon")
	vbox.add_child(icon)
	
	# Stats summary (damage, range, cooldown)
	var stats_label := Label.new()
	stats_label.text = str(view.get("stats_summary", ""))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 1.0))
	stats_label.custom_minimum_size = Vector2(188, 40)
	vbox.add_child(stats_label)
	
	# Effects description inside a vertical ScrollContainer to constrain height
	var effects_scroll := ScrollContainer.new()
	# Use the vertical size flags property on Controls
	effects_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effects_scroll.custom_minimum_size = Vector2(188, 80)

	var effects_label := Label.new()
	effects_label.text = str(view.get("effects_summary", ""))
	effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects_label.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1))
	effects_label.add_theme_font_size_override("font_size", 11)
	effects_label.custom_minimum_size = Vector2(180, 0)
	effects_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	effects_scroll.add_child(effects_label)
	vbox.add_child(effects_scroll)
	
	# Select button with visual feedback
	var select_btn := Button.new()
	select_btn.text = "SELECT"
	select_btn.custom_minimum_size = Vector2(188, 36)
	select_btn.pressed.connect(_on_card_selected.bind(card, container))
	vbox.add_child(select_btn)
	
	_card_nodes.append(container)
	return container

func _on_card_selected(card: CardData, button: Control = null) -> void:
	if not _is_active:
		return
	
	# Visual feedback: highlight selected card
	if _selected_card_button != null and _selected_card_button != button:
		_on_card_button_hover_exit(_selected_card_button)
	_selected_card_button = button
	if button:
		var selected_style := _build_card_style(SELECTED_COLOR)
		button.add_theme_stylebox_override("panel", selected_style)
	
	# Delegate workflow state to RewardFlowState
	_flow_state.select_card(card)
	
	# If replacement is required, RewardFlowState will transition to SLOT_PENDING
	# and we'll receive _on_flow_state_changed() signal to show slot selection UI
	if _flow_state.is_awaiting_slot_selection():
		await get_tree().create_timer(0.15).timeout
		_show_replace_selection()
	elif _flow_state.is_complete():
		# Direct completion (no replacement needed)
		hide_reward()
		card_selected.emit(card)

func _on_card_button_hover_enter(button: Control) -> void:
	if button == _selected_card_button:
		return  # Don't override selected state on hover
	var hover_style := _build_card_style(HOVER_COLOR)
	button.add_theme_stylebox_override("panel", hover_style)

func _on_card_button_hover_exit(button: Control) -> void:
	if button == _selected_card_button:
		var selected_style := _build_card_style(SELECTED_COLOR)
		button.add_theme_stylebox_override("panel", selected_style)
		return
	var normal_style := _build_card_style(NORMAL_COLOR)
	button.add_theme_stylebox_override("panel", normal_style)

func _get_category_color(category: String) -> Color:
	match category:
		"strength":
			return Color(1.0, 0.6, 0.4, 1.0)  # Orange
		"agility":
			return Color(0.6, 1.0, 0.6, 1.0)  # Green
		"magic":
			return Color(0.8, 0.6, 1.0, 1.0)  # Purple
		_:
			return Color(0.8, 0.8, 0.8, 1.0)  # Gray

func _build_card_stats_text(card: CardData) -> String:
	var stats: Array[String] = []
	stats.append("DMG: %d (×%.1f)" % [card.base_damage, card.damage_scaling])
	stats.append("Range: %d" % card.range)
	stats.append("Cooldown: %d" % card.cooldown)
	return " | ".join(stats)

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

func _refresh_slot_selection() -> void:
	title_label.text = "Hotbar Full - Select Slot to Replace"
	
	# Create header for clarity
	var header := Label.new()
	header.text = "Which card will you replace?"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
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
		card_name.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.8))
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 0.8)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.32, 0.38, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style

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

## Flow state signal handlers

func _on_flow_state_changed(new_state: int, _old_state: int) -> void:
	# Presentation updates based on workflow state changes
	# RewardFlowState owns the state; UI reacts to it
	match RewardFlowState.WorkflowState.values()[new_state]:
		RewardFlowState.WorkflowState.SHOWING_REWARDS:
			print("[CardRewardUI] Flow state: showing rewards")
		RewardFlowState.WorkflowState.SLOT_PENDING:
			print("[CardRewardUI] Flow state: awaiting slot selection")
		RewardFlowState.WorkflowState.COMPLETE:
			print("[CardRewardUI] Flow state: complete (transitioning to idle)")

func _on_reward_flow_completed(selected_card: CardData, slot_index: int) -> void:
	# Forward the completed workflow event to upstream handlers
	if slot_index >= 0:
		card_replace_selected.emit(selected_card, slot_index)
	else:
		card_selected.emit(selected_card)

func _build_reward_description(card: CardData) -> String:
	return card.description

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
