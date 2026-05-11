extends CanvasLayer
class_name PauseMenu

signal exit_requested
signal store_opened

const UPGRADES = {
	"hp": ["base_hp", "max_hp"],
	"str": ["base_str", "strength_modifier"],
	"mag": ["base_mag", "magic_modifier"],
	"dex": ["base_dex", "dexterity_modifier"]
}

const UPGRADE_COST := 50

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
	get_tree().paused = true
	_set_panel(0)
	_update_gold_labels()

func close_menu():
	is_open = false
	visible = false
	if options_menu:
		options_menu.close()
	get_tree().paused = false

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

	var stats = ["hp", "str", "mag", "dex"]

	for i in upgrade_buttons.size():
		var stat = stats[i]
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

	var ok = save_mgr.gold >= UPGRADE_COST
	for b in upgrade_buttons:
		b.disabled = not ok

func _update_gold_labels() -> void:
	var save := save_mgr if save_mgr else get_node_or_null("/root/SaveManager")
	if pause_gold_label and save:
		pause_gold_label.text = "Oro: %d" % save.gold
	if gold_label and save:
		gold_label.text = "Oro: %d" % save.gold

func _on_gold_changed(_amount: int) -> void:
	_update_gold_labels()

# ---------------- ACTIONS ----------------

func _on_upgrade_pressed(stat):
	if not save_mgr or not player_stats:
		return
	if save_mgr.gold < UPGRADE_COST:
		return

	var u = UPGRADES.get(stat)
	if not u:
		return

	save_mgr.gold -= UPGRADE_COST

	player_stats.set(u[0], player_stats.get(u[0]) + 1)

	if player_stats.stats:
		player_stats.stats.set(u[1], player_stats.stats.get(u[1]) + 1)

	save_mgr.save_game()
	_update_store()