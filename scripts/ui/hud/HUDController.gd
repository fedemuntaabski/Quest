extends CanvasLayer
class_name HUDController

signal hotbar_slot_pressed(index: int)
signal reward_card_selected(card: CardData)
signal reward_skipped
signal reward_card_replace_selected(card: CardData, slot_index: int)
signal hud_ready  # warning-ignore:unused_signal # Emitted after full HUD initialization (used by CardSystemController for deferred binding)

@onready var stat_panel: StatPanelUI = $Control/StatsHUD/MarginContainer/StatPanelUI
@onready var stats_hud_panel: PanelContainer = $Control/StatsHUD

@onready var card_panel: CardPanelUI = get_node_or_null("Control/CardPanelUI") as CardPanelUI
@onready var timer_ui: TimerUI = $Control/TimerUI
@onready var hotbar_bar: HBoxContainer = $Control/HotbarBar
@onready var card_tooltip: CardTooltip = $CardTooltip
@onready var card_reward_ui: CardRewardUI = $CardRewardUI if has_node("CardRewardUI") else null
@onready var roll_label: Label = $Control/RollLabel if has_node("Control/RollLabel") else null
@onready var potion_button: Button = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/PotionButton") as Button
@onready var potion_count_label: Label = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/PotionCount") as Label
@onready var potion_icon: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/IconPotion") as Control

@onready var stat_tooltip: PanelContainer = get_node_or_null("Control/StatTooltip") as PanelContainer
@onready var stat_tooltip_label: Label = get_node_or_null("Control/StatTooltip/Label") as Label

@onready var icon_hp: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowHP/IconHP") as Control
@onready var icon_strength: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowStrength/IconStrength") as Control
@onready var icon_magic: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowMagic/IconMagic") as Control
@onready var icon_dexterity: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowDexterity/IconDexterity") as Control

@onready var current_room_label: Label = get_node_or_null("Control/CurrentRoomLabel") as Label
@onready var enemies_label: Label = get_node_or_null("Control/EnemiesLabel") as Label

var hotbar_slots: Array = []
var _bound_card_manager: CardManager = null
var _roll_label_tween: Tween = null
var _potion_controller = null
var _bound_stats: CharacterStats = null
# Tooltip debounce is owned by CardTooltip. HUDController delegates tooltip timing.

func _ready() -> void:
	add_to_group("hud")
	# Allow HUD to continue processing while the SceneTree is paused (reward/victory overlays still interactive)
	# (pause behavior is handled by scene pause settings)
	_setup_hotbar()
	_setup_reward_ui()
	# Initialize potion controller to own potion UI/logic
	_init_potion_controller()
	_setup_stat_tooltips()

	# Tooltip debounce is handled by CardTooltip itself; HUDController delegates show/hide requests.

	var ps = get_node_or_null("/root/PlayerStats")
	if ps:
		_bind_player_stats(ps)
	
	# Signal that HUD is fully initialized and ready for card system binding
	call_deferred("_emit_hud_ready")

func _setup_hotbar() -> void:
	if hotbar_bar == null:
		return

	hotbar_slots.clear()
	for child in hotbar_bar.get_children():
		if child is HotbarSlot:
			hotbar_slots.append(child)
			# Pass the tooltip node directly so slots can call tooltip APIs without HUD mediation
			child.set_tooltip_host(card_tooltip)
			if not child.slot_pressed.is_connected(_on_hotbar_slot_pressed):
				child.slot_pressed.connect(_on_hotbar_slot_pressed)

func _setup_reward_ui() -> void:
	if card_reward_ui == null:
		return
	# Ensure reward UI processes during paused state (if configured in-scene)
	if not card_reward_ui.card_selected.is_connected(_on_reward_card_selected):
		card_reward_ui.card_selected.connect(_on_reward_card_selected)
	if not card_reward_ui.reward_skipped.is_connected(_on_reward_skipped):
		card_reward_ui.reward_skipped.connect(_on_reward_skipped)
	if not card_reward_ui.card_replace_selected.is_connected(_on_reward_card_replace_selected):
		card_reward_ui.card_replace_selected.connect(_on_reward_card_replace_selected)

func _init_potion_controller() -> void:
	if _potion_controller != null:
		return
	_potion_controller = get_node_or_null("PotionController")
	if _potion_controller == null:
		# Fallback for older scenes that do not yet include the node.
		var PotionController = preload("res://scripts/ui/hud/PotionController.gd")
		_potion_controller = PotionController.new()
		add_child(_potion_controller)
	# Provide HUD nodes (they may be null if scene differs)
	_potion_controller.setup(potion_button, potion_count_label, potion_icon)

func _on_hotbar_slot_pressed(index: int) -> void:
	hotbar_slot_pressed.emit(index)

func _on_reward_card_selected(card: CardData) -> void:
	reward_card_selected.emit(card)

func _on_reward_skipped() -> void:
	reward_skipped.emit()

func _on_reward_card_replace_selected(card: CardData, slot_index: int) -> void:
	reward_card_replace_selected.emit(card, slot_index)

func _bind_player_stats(ps: PlayerStats) -> void:
	if ps == null:
		return
	if not ps.stats_changed.is_connected(_on_player_stats_changed):
		ps.stats_changed.connect(_on_player_stats_changed)

	if ps.stats:
		if _potion_controller and _potion_controller.has_method("bind_stats"):
			_potion_controller.bind_stats(ps.stats)
		_on_player_stats_changed(ps.stats)

func _on_player_stats_changed(stats: CharacterStats) -> void:
	if stats == null:
		return
	if _bound_stats != stats:
		if _bound_stats and _bound_stats.hp_changed.is_connected(_on_hp_changed):
			_bound_stats.hp_changed.disconnect(_on_hp_changed)
		_bound_stats = stats
		if not stats.hp_changed.is_connected(_on_hp_changed):
			stats.hp_changed.connect(_on_hp_changed)
		if _potion_controller and _potion_controller.has_method("bind_stats"):
			_potion_controller.bind_stats(stats)

	_on_stats_changed(stats)

func _on_stats_changed(stats: CharacterStats) -> void:
	stat_panel.update_stats(stats)

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if stat_panel:
		stat_panel.update_hp(current_hp, max_hp)
	if _potion_controller:
		_potion_controller.refresh()

func update_room_timer(time_left: float, _total: float, color: Color) -> void:
	if timer_ui:
		timer_ui.set_time(time_left, color)

func update_current_room(id: int) -> void:
	if current_room_label:
		current_room_label.text = "Room: %d" % id

func update_enemies_remaining(count: int) -> void:
	if enemies_label:
		enemies_label.text = "Enemies: %d" % count

func update_hotbar(cards_payload: Array, active_index: int) -> void:
	if not hotbar_slots.is_empty():
		for i in range(hotbar_slots.size()):
			var slot: HotbarSlot = hotbar_slots[i]
			if i < cards_payload.size():
				var card_dict = cards_payload[i]
				# Convert dictionary payload to typed CardDisplayData
				var display_data: CardDisplayData = null
				if card_dict is Dictionary and not card_dict.is_empty():
					# Extract CardData and runtime state from payload
					var card_data = card_dict.get("card") as CardData
					if card_data != null:
						display_data = CardPresentationAdapter.create_display_data(card_data, card_dict)
				
				if display_data != null:
					slot.set_card(display_data)
				else:
					slot.set_card(null)
			else:
				slot.set_card(null)

			slot.set_selected(i == active_index)
	
	# Also update the Cards panel if present
	update_cards_panel(cards_payload)

func update_cards_panel(cards_payload: Array) -> void:
	if card_panel:
		var display_data_array: Array[CardDisplayData] = []
		for card_dict in cards_payload:
			if card_dict is Dictionary and not card_dict.is_empty():
				var card_data = card_dict.get("card") as CardData
				if card_data != null:
					var display_data = CardPresentationAdapter.create_display_data(card_data, card_dict)
					display_data_array.append(display_data)
				else:
					display_data_array.append(null)
			else:
				display_data_array.append(null)
		card_panel.refresh(display_data_array)

func show_card_tooltip(data: CardDisplayData) -> void:
	# Delegate tooltip presentation (debounce + show) to CardTooltip to clarify ownership
	if card_tooltip == null:
		return
	if card_tooltip.has_method("request_show"):
		card_tooltip.request_show(data)
	else:
		# Fallback: immediate show
		card_tooltip.set_card(data)

func hide_card_tooltip() -> void:
	# Delegate hide to CardTooltip
	if card_tooltip == null:
		return
	if card_tooltip.has_method("request_hide"):
		card_tooltip.request_hide()
	else:
		card_tooltip.visible = false
		card_tooltip.set_card(null)

func set_roll_label_from_result(result: Dictionary) -> void:
	if roll_label == null:
		return
	if result == null or result.is_empty():
		roll_label.visible = false
		roll_label.text = ""
		return

	var hit: bool = bool(result.get("hit", false))
	var crit: bool = bool(result.get("crit", false))
	var damage: int = int(result.get("damage", 0))
	var reason: String = str(result.get("reason", ""))
	var dice_roll: int = int(result.get("dice_roll", 0))
	var multiplier: float = float(result.get("damage_multiplier", 0.0))

	var text := ""
	var color := Color(0.95, 0.95, 0.95, 1.0)

	if hit:
		if crit:
			text = "CRÍTICO"
			color = Color(1.0, 0.9, 0.45, 1.0)
		else:
			text = "IMPACTO"
			color = Color(0.62, 1.0, 0.62, 1.0)

		if damage > 0:
			text += " · %d DAÑO" % damage

		if dice_roll > 0:
			text += "\n🎲 Tirada: %d" % dice_roll

	else:
		text = "FALLO"
		color = Color(1.0, 0.55, 0.55, 1.0)

		if not reason.is_empty() and reason != "null":
			text += "\n%s" % reason.capitalize()

	_show_roll_label_text(text, color)

func _show_roll_label_text(text: String, color: Color) -> void:
	if roll_label == null:
		return

	if _roll_label_tween:
		_roll_label_tween.kill()
		_roll_label_tween = null

	roll_label.visible = true
	roll_label.text = text
	roll_label.modulate = color
	roll_label.modulate.a = 0.0

	_roll_label_tween = create_tween()
	_roll_label_tween.tween_property(roll_label, "modulate:a", 1.0, 0.08)
	_roll_label_tween.tween_interval(1.55)
	_roll_label_tween.tween_property(roll_label, "modulate:a", 0.0, 0.22)
	_roll_label_tween.tween_callback(func() -> void:
		if roll_label:
			roll_label.visible = false
	)


func show_simple_tooltip(text: String, global_pos = null) -> void:
	if stat_tooltip == null or stat_tooltip_label == null:
		return
	stat_tooltip_label.text = text
	stat_tooltip.visible = true
	if global_pos != null:
		stat_tooltip.global_position = global_pos
	else:
		# default position to right of stats panel
		var panel_rect := stats_hud_panel.get_global_rect() if stats_hud_panel else stat_panel.get_global_rect()
		stat_tooltip.global_position = panel_rect.position + Vector2(panel_rect.size.x + 12.0, 0.0)

func hide_simple_tooltip() -> void:
	if stat_tooltip:
		stat_tooltip.visible = false

func _setup_stat_tooltips() -> void:
	# Stat tooltips (HP, Strength, etc) are shown on hover
	# Handled by separate StatIcon nodes that manage their own tooltips
	pass

## Card Manager Binding
## Establishes the connection between CardManager and UI to receive card state updates

func bind_card_manager(manager: CardManager) -> void:
	if manager == null:
		return
	if _bound_card_manager != null:
		if _bound_card_manager.ui_state_changed.is_connected(_on_card_ui_state_changed):
			_bound_card_manager.ui_state_changed.disconnect(_on_card_ui_state_changed)
	
	_bound_card_manager = manager
	if not _bound_card_manager.ui_state_changed.is_connected(_on_card_ui_state_changed):
		_bound_card_manager.ui_state_changed.connect(_on_card_ui_state_changed)
	
	_on_card_ui_state_changed(_bound_card_manager.get_equipped_payload(), _bound_card_manager.active_index)

func _on_card_ui_state_changed(cards_payload: Array, active_index: int) -> void:
	update_hotbar(cards_payload, active_index)

func show_reward_selection(cards: Array, requires_replace: bool = false, equipped_slots: Array = []) -> void:
	if card_reward_ui:
		card_reward_ui.show_reward(cards, requires_replace, equipped_slots)

func hide_reward_selection() -> void:
	if card_reward_ui:
		card_reward_ui.hide_reward()


func _emit_hud_ready() -> void:
	hud_ready.emit()
