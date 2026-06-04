extends CanvasLayer
class_name HUDController

signal hotbar_slot_pressed(index: int)
signal hud_ready

@onready var stat_panel: StatPanelUI = $Control/StatsHUD/MarginContainer/StatPanelUI
@onready var stats_hud_panel: PanelContainer = $Control/StatsHUD

@onready var card_panel: CardPanelUI = get_node_or_null("Control/CardPanelUI") as CardPanelUI
@onready var timer_ui: TimerUI = $Control/TimerUI
@onready var hotbar_bar: HBoxContainer = $Control/HotbarBar
@onready var card_tooltip: CardTooltip = $CardTooltip
@onready var card_reward_ui: CardRewardUI = $CardRewardUI if has_node("CardRewardUI") else null
@onready var roll_label: Label = $Control/RollLabel if has_node("Control/RollLabel") else null

@onready var potion_button: Button = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/PotionButton")
@onready var potion_count_label: Label = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/PotionCount")
@onready var potion_icon: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowPotion/IconPotion")

@onready var stat_tooltip: PanelContainer = get_node_or_null("Control/StatTooltip")
@onready var stat_tooltip_label: Label = get_node_or_null("Control/StatTooltip/Label")

@onready var icon_hp: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowHP/IconHP")
@onready var icon_strength: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowStrength/IconStrength")
@onready var icon_magic: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowMagic/IconMagic")
@onready var icon_dexterity: Control = get_node_or_null("Control/StatsHUD/MarginContainer/StatPanelUI/StatRowDexterity/IconDexterity")

@onready var current_room_label: Label = get_node_or_null("Control/CurrentRoomLabel")
@onready var enemies_label: Label = get_node_or_null("Control/EnemiesLabel")

var hotbar_slots: Array = []

var _roll_label_tween: Tween
var _potion_controller: PotionController

var _bound_stats: CharacterStats
var _bound_player_stats: PlayerStats


func _ready() -> void:
	add_to_group("hud")

	_setup_hotbar()
	_init_potion_controller()

	var ps := ManagerLocator.get_player_stats()
	if ps:
		_bind_player_stats(ps)

	call_deferred("emit_signal", "hud_ready")


# ---------------- HOTBAR ----------------

func _setup_hotbar() -> void:
	if hotbar_bar == null:
		return

	hotbar_slots.clear()

	for child in hotbar_bar.get_children():
		if child is HotbarSlot:
			hotbar_slots.append(child)

			child.set_tooltip_host(card_tooltip)

			if not child.slot_pressed.is_connected(_on_hotbar_slot_pressed):
				child.slot_pressed.connect(_on_hotbar_slot_pressed)


func _on_hotbar_slot_pressed(index: int) -> void:
	hotbar_slot_pressed.emit(index)


# ---------------- POTION ----------------

func _init_potion_controller() -> void:
	if _potion_controller != null:
		return

	_potion_controller = get_node_or_null("PotionController") as PotionController

	if _potion_controller == null:
		push_error("[HUDController] PotionController node is missing")
		return

	_potion_controller.setup(potion_button, potion_count_label, potion_icon)


# ---------------- PLAYER STATS BINDING ----------------

func _bind_player_stats(ps: PlayerStats) -> void:
	if ps == null:
		return

	if _bound_player_stats and _bound_player_stats.stats_changed.is_connected(_on_player_stats_changed):
		_bound_player_stats.stats_changed.disconnect(_on_player_stats_changed)

	_bound_player_stats = ps

	if not ps.stats_changed.is_connected(_on_player_stats_changed):
		ps.stats_changed.connect(_on_player_stats_changed)

	if ps.stats:
		_potion_controller.bind_stats(ps.stats)
		_on_player_stats_changed(ps.stats)


func _on_player_stats_changed(stats: CharacterStats) -> void:
	if stats == null:
		return

	if _bound_stats != stats:
		if _bound_stats:
			if _bound_stats.hp_changed.is_connected(_on_hp_changed):
				_bound_stats.hp_changed.disconnect(_on_hp_changed)
			if _bound_stats.potion_used.is_connected(_on_potion_used):
				_bound_stats.potion_used.disconnect(_on_potion_used)

		_bound_stats = stats

		if not stats.hp_changed.is_connected(_on_hp_changed):
			stats.hp_changed.connect(_on_hp_changed)
		if not stats.potion_used.is_connected(_on_potion_used):
			stats.potion_used.connect(_on_potion_used)

		if _potion_controller:
			_potion_controller.bind_stats(stats)

	stat_panel.update_stats(stats)


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	if stat_panel:
		stat_panel.update_hp(current_hp, max_hp)

	if _potion_controller:
		_potion_controller.refresh()


func _on_potion_used(_heal_amount: int, _remaining: int) -> void:
	if _bound_stats and stat_panel:
		stat_panel.update_hp(_bound_stats.current_hp, _bound_stats.max_hp)

	if _potion_controller:
		_potion_controller.refresh()


# ---------------- ROOM / UI UPDATES ----------------

func update_room_timer(time_left: float, _total: float, color: Color) -> void:
	if timer_ui:
		timer_ui.set_time(time_left, color)


func update_current_room(id: int) -> void:
	if current_room_label:
		current_room_label.text = "Room: %d" % id


func update_enemies_remaining(count: int) -> void:
	if enemies_label:
		enemies_label.text = "Enemies: %d" % count


# ---------------- HOTBAR REFRESH ----------------

func update_hotbar(cards_payload: Array, active_index: int) -> void:
	_refresh_hotbar_slots(cards_payload, active_index)
	_refresh_card_panel(cards_payload)


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


func _refresh_card_panel(cards_payload: Array) -> void:
	if card_panel == null:
		return

	var display_data_array: Array[CardDisplayData] = []

	for entry in cards_payload:
		display_data_array.append(
			CardPresentationAdapter.create_display_data_from_payload_entry(entry)
		)

	card_panel.refresh(display_data_array)


# ---------------- TOOLTIP ----------------

func show_card_tooltip(data: CardDisplayData) -> void:
	if card_tooltip:
		card_tooltip.request_show(data)


func hide_card_tooltip() -> void:
	if card_tooltip:
		card_tooltip.request_hide()


func show_simple_tooltip(text: String, global_pos: Variant = null) -> void:
	if stat_tooltip == null or stat_tooltip_label == null:
		return

	stat_tooltip_label.text = text
	stat_tooltip.visible = true

	var target_pos: Vector2

	if global_pos != null:
		target_pos = global_pos
	else:
		var panel_rect := stats_hud_panel.get_global_rect() if stats_hud_panel else stat_panel.get_global_rect()
		target_pos = panel_rect.position + Vector2(panel_rect.size.x + 12.0, 0.0)

	stat_tooltip.global_position = target_pos


func hide_simple_tooltip() -> void:
	if stat_tooltip:
		stat_tooltip.visible = false


# ---------------- COMBAT RESULT ----------------

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
		text = "CRÍTICO" if crit else "IMPACTO"
		color = QuestPalette.COMBAT_ROLL_CRIT if crit else QuestPalette.COMBAT_ROLL_HIT

		if damage > 0:
			text += " · %d DAÑO" % damage
		if dice_roll > 0:
			text += "\n🎲 Tirada: %d" % dice_roll
	else:
		text = "FALLO"
		color = QuestPalette.COMBAT_ROLL_FAIL

		if not reason.is_empty() and reason != "null":
			text += "\n%s" % reason.capitalize()

	_show_roll_label(text, color)


func _show_roll_label(text: String, color: Color) -> void:
	if roll_label == null:
		return

	if _roll_label_tween:
		_roll_label_tween.kill()

	roll_label.visible = true
	roll_label.text = text
	roll_label.modulate = color
	roll_label.modulate.a = 0.0

	_roll_label_tween = create_tween()
	_roll_label_tween.tween_property(roll_label, "modulate:a", 1.0, 0.08)
	_roll_label_tween.tween_interval(1.55)
	_roll_label_tween.tween_property(roll_label, "modulate:a", 0.0, 0.22)
	_roll_label_tween.tween_callback(func():
		roll_label.visible = false
	)
	