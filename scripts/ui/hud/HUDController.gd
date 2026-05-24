extends CanvasLayer
class_name HUDController

signal hotbar_slot_pressed(index: int)
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
var _roll_label_tween: Tween = null
var _potion_controller: PotionController = null
var _bound_stats: CharacterStats = null
# Tooltip debounce is owned by CardTooltip. HUDController delegates tooltip timing.

func _ready() -> void:
	add_to_group("hud")
	# Allow HUD to continue processing while the SceneTree is paused (reward/victory overlays still interactive)
	# (pause behavior is handled by scene pause settings)
	_setup_hotbar()
	# Initialize potion controller to own potion UI/logic
	_init_potion_controller()

	# Tooltip debounce is handled by CardTooltip itself; HUDController delegates show/hide requests.

	var ps = get_node_or_null("/root/PlayerStats")
	if ps:
		_bind_player_stats(ps)
	
	# Signal that HUD is fully initialized and ready for card system binding
	call_deferred("emit_signal", "hud_ready")

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

func _init_potion_controller() -> void:
	if _potion_controller != null:
		return
	_potion_controller = get_node_or_null("PotionController") as PotionController
	if _potion_controller == null:
		push_error("[HUDController] PotionController node is missing from the HUD scene")
		return
	# Provide HUD nodes if present.
	_potion_controller.setup(potion_button, potion_count_label, potion_icon)

func _on_hotbar_slot_pressed(index: int) -> void:
	hotbar_slot_pressed.emit(index)

func _bind_player_stats(ps: PlayerStats) -> void:
	if ps == null:
		return
	if not ps.stats_changed.is_connected(_on_player_stats_changed):
		ps.stats_changed.connect(_on_player_stats_changed)

	if ps.stats:
		if _potion_controller:
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
		if _potion_controller:
			_potion_controller.bind_stats(stats)
	stat_panel.update_stats(stats)

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if stat_panel:
		stat_panel.update_hp(current_hp, max_hp)
	if _potion_controller:
		_potion_controller.refresh()

## Forwards the room timer display to the dedicated TimerUI leaf.
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
	_refresh_hotbar_slots(cards_payload, active_index)
	_refresh_card_panel(cards_payload)

## Updates the visible hotbar slots from the authoritative card payload.
func _refresh_hotbar_slots(cards_payload: Array, active_index: int) -> void:
	if hotbar_slots.is_empty():
		return

	for i in range(hotbar_slots.size()):
		var slot: HotbarSlot = hotbar_slots[i]
		if i < cards_payload.size():
			var display_data: CardDisplayData = CardPresentationAdapter.create_display_data_from_payload_entry(cards_payload[i])
			slot.set_card(display_data)
		else:
			slot.set_card(null)

		slot.set_selected(i == active_index)

## Mirrors the same payload into the detailed card panel when that view is present.
func _refresh_card_panel(cards_payload: Array) -> void:
	if card_panel == null:
		return

	var display_data_array: Array[CardDisplayData] = []
	for card_entry in cards_payload:
		display_data_array.append(CardPresentationAdapter.create_display_data_from_payload_entry(card_entry))
	card_panel.refresh(display_data_array)

func show_card_tooltip(data: CardDisplayData) -> void:
	# Delegate tooltip presentation (debounce + show) to CardTooltip to clarify ownership
	if card_tooltip == null:
		return
	card_tooltip.request_show(data)

func hide_card_tooltip() -> void:
	# Delegate hide to CardTooltip
	if card_tooltip == null:
		return
	card_tooltip.request_hide()

func show_combat_result(result: Dictionary) -> void:
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

	var text := ""
	var color := QuestPalette.UI_TEXT_PRIMARY

	if hit:
		if crit:
			text = "CRÍTICO"
			color = QuestPalette.COMBAT_ROLL_CRIT
		else:
			text = "IMPACTO"
			color = QuestPalette.COMBAT_ROLL_HIT

		if damage > 0:
			text += " · %d DAÑO" % damage

		if dice_roll > 0:
			text += "\n🎲 Tirada: %d" % dice_roll

	else:
		text = "FALLO"
		color = QuestPalette.COMBAT_ROLL_FAIL

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

## Opens the reward overlay and leaves workflow details to CardRewardUI.
