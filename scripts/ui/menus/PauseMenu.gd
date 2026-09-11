extends CanvasLayer
class_name PauseMenu

const StatBalanceScript = preload("res://scripts/core/stats/StatBalance.gd")

signal exit_requested

const UPGRADES = {
	"hp": {"stat": "hp", "label": "Vitalidad", "effect": "+2 Vida maxima ", "value": 2},
	"str": {"stat": "strength", "label": "Fuerza", "effect": "+1 Fuerza maxima", "value": 1},
	"mag": {"stat": "magic", "label": "Magia", "effect": "+1 Magia Maxima", "value": 1},
	"dex": {"stat": "dexterity", "label": "Agilidad", "effect": "+1 Agilidad Maxima", "value": 1}
}

@export var save_mgr: Node
@export var player_stats: Node
@export var confirm_exit_on_run: bool = true

@onready var pause_panel = $CenterContainer/PausePanel
@onready var options_menu: OptionsMenu = $OptionsMenu
@onready var store_panel = $StorePanel
@onready var exit_confirm_dialog: ConfirmationDialog = $ExitConfirmDialog

@onready var click_sfx: AudioStreamPlayer = $UIAudio/ClickSound
@onready var hover_sfx: AudioStreamPlayer = $UIAudio/HoverSound

@onready var panels = [pause_panel, options_menu, store_panel]

@onready var options_button = $CenterContainer/PausePanel/PauseVBox/OptionsButton
@onready var store_button = $CenterContainer/PausePanel/PauseVBox/StoreButton
@onready var exit_button = $CenterContainer/PausePanel/PauseVBox/ExitButton
@onready var pause_gold_label: Label = $CenterContainer/PausePanel/PauseVBox/PauseGoldLabel

@onready var store_back_button: Button = $StorePanel/StoreCenterContainer/StoreCard/StoreVBox/StoreBackButton

@onready var gold_label = $StorePanel/StoreCenterContainer/StoreCard/StoreVBox/GoldLabel

@onready var upgrade_buttons = [
	$StorePanel/StoreCenterContainer/StoreCard/StoreVBox/UpgradeHPButton,
	$StorePanel/StoreCenterContainer/StoreCard/StoreVBox/UpgradeSTRButton,
	$StorePanel/StoreCenterContainer/StoreCard/StoreVBox/UpgradeMAGButton,
	$StorePanel/StoreCenterContainer/StoreCard/StoreVBox/UpgradeDEXButton
]

var is_open := false

# PHASE 2: Transaction error feedback
var _error_message_timer: float = 0.0
var _error_message: String = ""

# ---------------- INIT ----------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)

	visible = false
	is_open = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	click_sfx.stream = load("res://assets/audio/click.mp3")
	hover_sfx.stream = load("res://assets/audio/hover.mp3")

	if save_mgr == null:
		save_mgr = ManagerLocator.get_save_manager()
	if player_stats == null:
		player_stats = ManagerLocator.get_player_stats()

	_connect()
	if options_menu and not options_menu.closed.is_connected(_on_options_menu_closed):
		options_menu.closed.connect(_on_options_menu_closed)
	if exit_confirm_dialog and not exit_confirm_dialog.confirmed.is_connected(_on_exit_confirmed):
		exit_confirm_dialog.confirmed.connect(_on_exit_confirmed)
	if exit_confirm_dialog and not exit_confirm_dialog.canceled.is_connected(_on_exit_canceled):
		exit_confirm_dialog.canceled.connect(_on_exit_canceled)
	if exit_confirm_dialog:
		exit_confirm_dialog.ok_button_text = "OK"
		exit_confirm_dialog.cancel_button_text = "Cancelar"

	_apply_theme()

	_set_panel(0)
	_update_gold_labels()

	var currency := _get_currency_manager()
	if currency and not currency.gold_changed.is_connected(_on_gold_changed):
		currency.gold_changed.connect(_on_gold_changed)

func _process(delta: float) -> void:
	# PHASE 2: Handle error message display timeout
	if _error_message_timer > 0:
		_error_message_timer -= delta

# ---------------- OPEN / CLOSE ----------------

func open_menu():
	is_open = true
	visible = true
	_set_panel(0)
	_update_gold_labels()
	
	var gsm := _get_game_state_manager()
	if gsm:
		gsm.request_pause()

func close_menu():
	is_open = false
	visible = false
	if options_menu:
		options_menu.close()
	
	var gsm := _get_game_state_manager()
	if gsm:
		gsm.request_resume()

func toggle_menu():
	if is_open:
		close_menu()
	else:
		open_menu()

# ---------------- INPUT (FIX REAL) ----------------

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"):
			toggle_menu()

# ---------------- UI ----------------

func _set_panel(i: int) -> void:
	for p in panels:
		p.visible = false

	if i == 1:
		if options_menu:
			options_menu.open()
		return

	if options_menu:
		options_menu.close()
	panels[i].visible = true

func _on_options_menu_closed() -> void:
	_set_panel(0)

# ---------------- CONNECT ----------------

func _connect() -> void:
	options_button.pressed.connect(func(): _play_click(); _set_panel(1))
	store_button.pressed.connect(func(): _play_click(); _set_panel(2); _update_store())
	exit_button.pressed.connect(func(): _play_click(); _request_exit())

	var all_buttons = [options_button, store_button, exit_button]
	for b in all_buttons:
		b.mouse_entered.connect(_play_hover)

	if store_back_button:
		store_back_button.pressed.connect(func(): _play_click(); _set_panel(0))
		store_back_button.mouse_entered.connect(_play_hover)

	var stats: Array[String] = ["hp", "str", "mag", "dex"]

	for i in upgrade_buttons.size():
		var stat: String = stats[i]
		upgrade_buttons[i].pressed.connect(func():
			_play_click()
			_on_upgrade_pressed(stat)
		)

	# Play hover SFX for upgrade buttons and ensure they show tooltips on hover
	for b in upgrade_buttons:
		if b:
			b.mouse_entered.connect(_play_hover)
			b.mouse_entered.connect(_on_upgrade_button_entered.bind(b))
			b.mouse_exited.connect(_on_upgrade_button_exited)


func _on_upgrade_button_entered(btn: Button) -> void:
	# Show HUD tooltip with full details if HUD exists
	_play_hover()
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() == 0:
		return
	var hud := hud_nodes[0]
	var hint := ""
	if btn.has_meta("upgrade_hint"):
		hint = str(btn.get_meta("upgrade_hint"))
	if hint == "":
		return
	# Position tooltip to the right of the button
	var rect := btn.get_global_rect()
	var pos := rect.position + Vector2(rect.size.x + 12.0, 0.0)
	hud.show_simple_tooltip(hint, pos)

func _on_upgrade_button_exited() -> void:
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	if hud_nodes.size() == 0:
		return
	var hud := hud_nodes[0]
	hud.hide_simple_tooltip()

func _request_exit() -> void:
	if confirm_exit_on_run and exit_confirm_dialog:
		_show_exit_confirm_dialog()
		return

	_emit_exit_requested()

func _on_exit_confirmed() -> void:
	_emit_exit_requested()

func _on_exit_canceled() -> void:
	_set_panel(0)

func _show_exit_confirm_dialog() -> void:
	exit_confirm_dialog.popup_centered()
	exit_confirm_dialog.position += Vector2i(0, 80)

func _emit_exit_requested() -> void:
	exit_requested.emit()

# ---------------- AUDIO ----------------

func _play_click():
	if click_sfx:
		click_sfx.play()

func _play_hover():
	if hover_sfx:
		hover_sfx.play()

# ---------------- STORE ----------------

func _update_store():
	if not save_mgr:
		return

	var currency := _get_currency_manager()
	var current_gold: int = currency.get_gold() if currency else save_mgr.gold
	gold_label.text = "Oro: %d" % current_gold
	
	# PHASE 2: Display transaction error if present
	if _error_message_timer > 0 and _error_message != "":
		gold_label.text = "%s - %s" % [gold_label.text, _error_message]

	var stats: Array[String] = ["hp", "str", "mag", "dex"]
	for i in upgrade_buttons.size():
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
		var affordable: bool = save_mgr.gold >= cost
		var button: Button = upgrade_buttons[i]
		button.disabled = not (can_upgrade and affordable)
		if can_upgrade:
			# Short two-line button text and full details in engine tooltip
			button.text = "%s\n%s | %dg" % [
				str(config.get("label", key.to_upper())),
				str(config.get("effect", "")),
				cost
			]
			button.set_meta("upgrade_hint", "%s\nNivel %d/%d\nCosto: %dg\n%s" % [
				str(config.get("label", key.to_upper())),
				level,
				max_level,
				cost,
				str(config.get("effect", ""))
			])
		else:
			button.text = "%s\nMAX NIVEL" % [
				str(config.get("label", key.to_upper()))
			]

func _update_gold_labels() -> void:
	var currency := _get_currency_manager()
	var current_gold: int = currency.get_gold() if currency else (save_mgr.gold if save_mgr else 0)
	if pause_gold_label:
		pause_gold_label.text = "Oro: %d" % current_gold
	if gold_label:
		gold_label.text = "Oro: %d" % current_gold

func _on_gold_changed(_amount: int) -> void:
	_update_gold_labels()
	_update_store()

# ---------------- ACTIONS ----------------

func _on_upgrade_pressed(stat: String):
	if not save_mgr or not player_stats:
		return
	var config: Dictionary = UPGRADES.get(stat, {})
	if config.is_empty():
		return

	var stat_name: String = str(config.get("stat", ""))
	if stat_name == "" or not player_stats.can_upgrade_stat(stat_name):
		return

	var level: int = player_stats.get_upgrade_level(stat_name)
	var cost := StatBalanceScript.get_upgrade_cost(level)
	
	var currency := _get_currency_manager()
	if currency == null:
		return
	
	# PHASE 2: Validate transaction atomically
	if not currency.spend_gold(cost):
		# Transaction failed: insufficient gold
		_show_error_message("Oro Insuficiente")
		_play_click()
		return

	# Transaction succeeded: apply upgrade
	var value_change := int(config.get("value", 1))
	var upgrade := {
		"card_name": "Store Upgrade",
		"stat_affected": stat_name,
		"value_change": value_change
	}
	if not player_stats.apply_upgrade(upgrade):
		push_warning("Upgrade apply failed after gold deduction for stat: %s" % stat_name)
		return

	_update_gold_labels()
	_update_store()

func _show_error_message(message: String) -> void:
	# PHASE 2: Display error feedback temporarily
	_error_message = message
	_error_message_timer = 3.0  # Show for 3 seconds

func _get_game_state_manager() -> GameStateManager:
	return get_tree().get_first_node_in_group("game_state_manager") as GameStateManager

func _get_currency_manager() -> CurrencyManager:
	return ManagerLocator.get_currency_manager() as CurrencyManager

func _apply_theme() -> void:
	if pause_panel:
		pause_panel.add_theme_stylebox_override("panel", ThemeManager.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, QuestPalette.GOLD_DARK, 3, 20))
	if pause_gold_label:
		pause_gold_label.add_theme_color_override("font_color", QuestPalette.GOLD)
	if gold_label:
		gold_label.add_theme_color_override("font_color", QuestPalette.GOLD)
	if options_button:
		_style_button(options_button)
	if store_button:
		_style_button(store_button)
	if store_back_button:
		_style_button(store_back_button)
	if exit_button:
		_style_button(exit_button, true)

func _style_button(button: Button, danger: bool = false) -> void:
	if button == null:
		return

	var border_base: Color = QuestPalette.BLOOD if danger else QuestPalette.GOLD_DARK
	var border_hover: Color = QuestPalette.BLOOD_LIGHT if danger else QuestPalette.GOLD_LIGHT
	var text_base: Color = QuestPalette.PARCHMENT
	var text_hover: Color = QuestPalette.PARCHMENT_LIGHT
	var text_pressed: Color = QuestPalette.GOLD if not danger else QuestPalette.BLOOD_LIGHT

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
