extends CanvasLayer
class_name PauseMenu

const UPGRADES = {
	"hp": ["base_hp", "max_hp"],
	"str": ["base_str", "strength_modifier"],
	"mag": ["base_mag", "magic_modifier"],
	"dex": ["base_dex", "dexterity_modifier"]
}

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "options"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

const RESOLUTION_PRESETS = [
	["1920x1080", Vector2i(1920, 1080)],
	["1600x900", Vector2i(1600, 900)],
	["1280x720", Vector2i(1280, 720)]
]

const UPGRADE_COST := 50

@export var save_mgr: SaveManager
@export var player_stats: PlayerStats

@onready var pause_panel = $CenterContainer/PausePanel
@onready var options_panel = $OptionsPanel
@onready var store_panel = $StorePanel

@onready var click_sfx: AudioStreamPlayer = $UIAudio/ClickSound
@onready var hover_sfx: AudioStreamPlayer = $UIAudio/HoverSound

@onready var panels = [pause_panel, options_panel, store_panel]

@onready var continue_button = $CenterContainer/PausePanel/PauseVBox/ContinueButton
@onready var options_button = $CenterContainer/PausePanel/PauseVBox/OptionsButton
@onready var store_button = $CenterContainer/PausePanel/PauseVBox/StoreButton
@onready var exit_button = $CenterContainer/PausePanel/PauseVBox/ExitButton

@onready var sliders = [
	$OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeSlider,
	$OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeSlider
]

@onready var labels = [
	$OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ClickVolumeRow/ClickVolumeValueLabel,
	$OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/HoverVolumeRow/HoverVolumeValueLabel
]

@onready var res_selector = $OptionsPanel/OptionsCenterContainer/OptionsCard/OptionsVBox/ResSelector

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

	_fill_res()
	_connect()

	load_settings()
	_update_volume()
	_set_panel(0)

# ---------------- OPEN / CLOSE ----------------

func open_menu():
	is_open = true
	visible = true
	get_tree().paused = true
	_set_panel(0)

func close_menu():
	is_open = false
	visible = false
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

func _set_panel(i):
	for p in panels:
		p.visible = false
	panels[i].visible = true

# ---------------- CONNECT ----------------

func _connect():
	continue_button.pressed.connect(func(): _play_click(); close_menu())
	options_button.pressed.connect(func(): _play_click(); _set_panel(1))
	store_button.pressed.connect(func(): _play_click(); _set_panel(2); _update_store())
	exit_button.pressed.connect(func(): _play_click(); _exit())

	var all_buttons = [
		continue_button,
		options_button,
		store_button,
		exit_button
	]

	for b in all_buttons:
		b.mouse_entered.connect(_play_hover)

	var stats = ["hp", "str", "mag", "dex"]

	for i in upgrade_buttons.size():
		var stat = stats[i]
		upgrade_buttons[i].pressed.connect(func():
			_play_click()
			_on_upgrade_pressed(stat)
		)

	for i in sliders.size():
		sliders[i].value_changed.connect(func(v): _update_label(i, v))

	res_selector.item_selected.connect(_res)

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

# ---------------- RES ----------------

func _fill_res():
	res_selector.clear()
	for r in RESOLUTION_PRESETS:
		res_selector.add_item(r[0])

func _res(i):
	var r = RESOLUTION_PRESETS[i][1]
	DisplayServer.window_set_size(r)
	get_tree().root.content_scale_size = r

# ---------------- LABELS ----------------

func _update_label(i, v):
	labels[i].text = "%d%%" % int(v * 100)

func _update_volume():
	for i in sliders.size():
		_update_label(i, sliders[i].value)

# ---------------- ACTIONS ----------------

func _exit():
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

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

# ---------------- SETTINGS ----------------

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	res_selector.select(cfg.get_value(SETTINGS_SECTION, "resolution_index", 0))
	sliders[0].value = cfg.get_value(SETTINGS_SECTION, "click_volume", 1.0)
	sliders[1].value = cfg.get_value(SETTINGS_SECTION, "hover_volume", 1.0)