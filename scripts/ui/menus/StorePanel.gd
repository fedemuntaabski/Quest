extends BaseSubPanel
class_name StorePanel

const StatBalanceScript = preload("res://scripts/core/stats/StatBalance.gd")

const UPGRADES = {
	"hp": {"stat": "hp", "label": "Vitalidad", "effect": "+2 Vida maxima ", "value": 2},
	"str": {"stat": "strength", "label": "Fuerza", "effect": "+1 Fuerza maxima", "value": 1},
	"mag": {"stat": "magic", "label": "Magia", "effect": "+1 Magia Maxima", "value": 1},
	"dex": {"stat": "dexterity", "label": "Agilidad", "effect": "+1 Agilidad Maxima", "value": 1}
}

@export var player_stats: PlayerStats
@export var click_player_path: NodePath
@export var hover_player_path: NodePath

@onready var click_player: AudioStreamPlayer = get_node_or_null(click_player_path)
@onready var hover_player: AudioStreamPlayer = get_node_or_null(hover_player_path)

@onready var gold_label: Label = %GoldLabel
@onready var store_back_button: Button = %StoreBackButton
@onready var store_card: Panel = %StoreCard

@onready var upgrade_cards: Array[StoreUpgradeCard] = [
	%UpgradeHPCard,
	%UpgradeSTRCard,
	%UpgradeMAGCard,
	%UpgradeDEXCard
]

const STAT_COLORS: Dictionary = {
	"hp": QuestPalette.CARD_VITALITY,
	"str": QuestPalette.CARD_STRENGTH,
	"mag": QuestPalette.CARD_MAGIC,
	"dex": QuestPalette.CARD_AGILITY,
}

var _error_message_timer: float = 0.0
var _error_message: String = ""


func _on_base_ready() -> void:
	set_audio_players(click_player, hover_player)

	if player_stats == null:
		player_stats = ManagerLocator.get_player_stats()

	visible = false

	connect_button(store_back_button, _on_back_pressed)

	var stats: Array[String] = ["hp", "str", "mag", "dex"]
	for i in upgrade_cards.size():
		var stat: String = stats[i]
		var card: StoreUpgradeCard = upgrade_cards[i]
		card.configure(stat, STAT_COLORS.get(stat, QuestPalette.GOLD))
		card.upgrade_pressed.connect(_on_upgrade_pressed)
		card.hovered.connect(_on_upgrade_card_hovered.bind(card))
		card.unhovered.connect(_on_upgrade_card_unhovered)

	_apply_theme()
	_update_gold_label()

	animate_transitions = true
	fade_duration_in = 0.22
	fade_duration_out = 0.16
	add_fade_target(store_card, 1.0)
	add_scale_target(store_card)

	var currency := ManagerLocator.get_currency_manager()
	if currency and not currency.gold_changed.is_connected(_on_gold_changed):
		currency.gold_changed.connect(_on_gold_changed)

	if player_stats and not player_stats.stats_changed.is_connected(_on_stats_changed):
		player_stats.stats_changed.connect(_on_stats_changed)


func _process(delta: float) -> void:
	if _error_message_timer > 0:
		_error_message_timer -= delta


func _on_before_open() -> void:
	_update_gold_label()
	_update_store()


func _on_back_pressed() -> void:
	close()


func _on_gold_changed(_amount: int) -> void:
	_update_gold_label()
	_update_store()


func _on_stats_changed(_stats: CharacterStats) -> void:
	_update_store()


func _update_gold_label() -> void:
	var currency := ManagerLocator.get_currency_manager()
	var current_gold: int = currency.get_gold() if currency else 0
	if gold_label:
		gold_label.text = "Oro: %d" % current_gold


func _update_store() -> void:
	var currency := ManagerLocator.get_currency_manager()
	var current_gold: int = currency.get_gold() if currency else 0
	gold_label.text = "Oro: %d" % current_gold

	if _error_message_timer > 0 and _error_message != "":
		gold_label.text = "%s - %s" % [gold_label.text, _error_message]

	var stats: Array[String] = ["hp", "str", "mag", "dex"]
	for i in upgrade_cards.size():
		var key: String = stats[i]
		var config: Dictionary = UPGRADES.get(key, {})
		var stat_name: String = str(config.get("stat", ""))
		var level := 0
		var max_level := StatBalanceScript.MAX_UPGRADE_LEVEL
		if player_stats:
			level = player_stats.get_upgrade_level(stat_name)
			max_level = player_stats.get_max_upgrade_level()
		var cost := StatBalanceScript.get_upgrade_cost(level)
		var can_upgrade: bool = player_stats != null and player_stats.can_upgrade_stat(stat_name)
		var affordable: bool = current_gold >= cost
		upgrade_cards[i].set_data(
			str(config.get("label", key.to_upper())),
			str(config.get("effect", "")),
			level,
			max_level,
			cost,
			can_upgrade,
			affordable
		)


func _on_upgrade_pressed(stat: String) -> void:
	if not player_stats:
		return
	var config: Dictionary = UPGRADES.get(stat, {})
	if config.is_empty():
		return

	var stat_name: String = str(config.get("stat", ""))
	if stat_name == "" or not player_stats.can_upgrade_stat(stat_name):
		return

	var level: int = player_stats.get_upgrade_level(stat_name)
	var cost := StatBalanceScript.get_upgrade_cost(level)

	var currency := ManagerLocator.get_currency_manager()
	if currency == null:
		return

	if not currency.spend_gold(cost):
		_show_error_message("Oro Insuficiente")
		return

	var value_change := int(config.get("value", 1))
	var upgrade := {
		"card_name": "Store Upgrade",
		"stat_affected": stat_name,
		"value_change": value_change
	}
	if not player_stats.apply_upgrade(upgrade):
		currency.add_gold(cost)
		QuestLogger.warn(QuestLogger.Category.UI, "Upgrade apply failed after gold deduction for stat: %s, refunded %d gold" % [stat_name, cost])
		return

	_update_gold_label()
	_update_store()


func _show_error_message(message: String) -> void:
	_error_message = message
	_error_message_timer = 3.0


func _on_upgrade_card_hovered(hint: String, card: StoreUpgradeCard) -> void:
	if hint == "":
		return
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() == 0:
		return
	var hud := hud_nodes[0]
	var rect := card.get_global_rect()
	var pos := rect.position + Vector2(rect.size.x + 12.0, 0.0)
	hud.show_simple_tooltip(hint, pos)


func _on_upgrade_card_unhovered() -> void:
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() == 0:
		return
	var hud := hud_nodes[0]
	hud.hide_simple_tooltip()


func _apply_theme() -> void:
	if gold_label:
		gold_label.add_theme_color_override("font_color", QuestPalette.GOLD)
	if store_back_button:
		_style_button(store_back_button)


func _style_button(button: Button) -> void:
	if button == null:
		return

	var border_base: Color = QuestPalette.GOLD_DARK
	var border_hover: Color = QuestPalette.GOLD_LIGHT
	var text_base: Color = QuestPalette.PARCHMENT
	var text_hover: Color = QuestPalette.PARCHMENT_LIGHT
	var text_pressed: Color = QuestPalette.GOLD

	button.add_theme_color_override("font_color", text_base)
	button.add_theme_color_override("font_focus_color", text_hover)
	button.add_theme_color_override("font_hover_color", text_hover)
	button.add_theme_color_override("font_pressed_color", text_pressed)
	button.add_theme_color_override("font_outline_color", QuestPalette.INK)
	button.add_theme_constant_override("outline_size", 3)

	button.add_theme_stylebox_override("normal", ThemeManager.build_panel_style(QuestPalette.DUNGEON_MUD, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("pressed", ThemeManager.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, border_base, 3, 16, 16))
	button.add_theme_stylebox_override("hover", ThemeManager.build_panel_style(QuestPalette.DUNGEON_MUD, border_hover, 3, 16, 16))
	button.add_theme_stylebox_override("focus", ThemeManager.build_panel_style(QuestPalette.DUNGEON_MUD, QuestPalette.PARCHMENT_LIGHT, 4, 16, 16))
