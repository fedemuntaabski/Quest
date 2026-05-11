extends CanvasLayer
class_name PauseMenu

signal exit_requested
signal store_opened

const UPGRADES = {
	"hp": {"stat": "hp", "label": "Vitalidad", "effect": "+1 Vida maxima"},
	"str": {"stat": "strength", "label": "Fuerza", "effect": "+1 dano fisico"},
	"mag": {"stat": "magic", "label": "Magia", "effect": "+1 dano magico"},
	"dex": {"stat": "dexterity", "label": "Precision", "effect": "+1 precision/crit"}
}

const BASE_UPGRADE_COST := 50
const UPGRADE_COST_STEP := 25

@export var save_mgr: SaveManager
@export var player_stats: PlayerStats
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
		save_mgr = get_node_or_null("/root/SaveManager") as SaveManager
	if player_stats == null:
		player_stats = get_node_or_null("/root/PlayerStats") as PlayerStats

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

	_set_panel(0)
	_update_gold_labels()

	var currency := get_node_or_null("/root/CurrencyManager") as CurrencyManager
	if currency and not currency.gold_changed.is_connected(_on_gold_changed):
		currency.gold_changed.connect(_on_gold_changed)

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
	if i == 2:
		store_opened.emit()

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

func _on_options_menu_closed() -> void:
	_set_panel(0)

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

	gold_label.text = "Oro: %d" % save_mgr.gold

	var stats: Array[String] = ["hp", "str", "mag", "dex"]
	for i in upgrade_buttons.size():
		var key: String = stats[i]
		var config: Dictionary = UPGRADES.get(key, {})
		var stat_name: String = str(config.get("stat", ""))
		var level := 0
		var max_level := 10
		if player_stats:
			level = player_stats.get_upgrade_level(stat_name)
			max_level = player_stats.get_max_upgrade_level()
		var cost := _get_upgrade_cost(level)
		var can_upgrade := player_stats != null and player_stats.can_upgrade_stat(stat_name)
		var affordable := save_mgr.gold >= cost
		var button: Button = upgrade_buttons[i]
		button.disabled = not (can_upgrade and affordable)
		if can_upgrade:
			button.text = "%s\n%s\nCosto: %dg  |  Nivel %d/%d" % [
				str(config.get("label", key.to_upper())),
				str(config.get("effect", "")),
				cost,
				level,
				max_level
			]
		else:
			button.text = "%s\nMAX NIVEL" % [
				str(config.get("label", key.to_upper()))
			]

func _update_gold_labels() -> void:
	var save := save_mgr if save_mgr else get_node_or_null("/root/SaveManager")
	if pause_gold_label and save:
		pause_gold_label.text = "Oro: %d" % save.gold
	if gold_label and save:
		gold_label.text = "Oro: %d" % save.gold

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

	var level := player_stats.get_upgrade_level(stat_name)
	var cost := _get_upgrade_cost(level)
	if save_mgr.gold < cost:
		return

	var upgrade := {
		"card_name": "Store Upgrade",
		"stat_affected": stat_name,
		"value_change": 1
	}
	if not player_stats.apply_upgrade(upgrade):
		return

	save_mgr.gold -= cost

	save_mgr.save_game()
	_update_gold_labels()
	_update_store()

func _get_upgrade_cost(level: int) -> int:
	return BASE_UPGRADE_COST + (max(level, 0) * UPGRADE_COST_STEP)

func _get_game_state_manager() -> GameStateManager:
	return get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
