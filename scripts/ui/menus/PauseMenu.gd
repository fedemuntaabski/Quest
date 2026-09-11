extends BaseMenu
class_name PauseMenu

signal exit_requested

@export var save_mgr: SaveManager
@export var player_stats: PlayerStats
@export var confirm_exit_on_run: bool = true

@onready var pause_panel: Panel = %PausePanel
@onready var blur_rect: ColorRect = %BlurRect
@onready var dim_rect: ColorRect = %DimRect
@onready var options_menu: OptionsMenu = %OptionsMenu
@onready var store_panel: StorePanel = %StorePanel
@onready var exit_confirm_dialog: ExitConfirmDialog = %ExitConfirmDialog

@onready var options_button: Button = %OptionsButton
@onready var store_button: Button = %StoreButton
@onready var exit_button: Button = %ExitButton
@onready var pause_gold_label: Label = %PauseGoldLabel

@onready var panels: Array[Control] = [pause_panel, options_menu, store_panel]

# ---------------- INIT ----------------

func _on_base_ready() -> void:
	pause_game_on_open = true
	visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if save_mgr == null:
		save_mgr = ManagerLocator.get_save_manager()
	if player_stats == null:
		player_stats = ManagerLocator.get_player_stats()

	set_audio_players(%ClickSound, %HoverSound)

	_connect()

	if store_panel and not store_panel.menu_closed.is_connected(_on_store_panel_closed):
		store_panel.menu_closed.connect(_on_store_panel_closed)
	if options_menu and not options_menu.closed.is_connected(_on_options_menu_closed):
		options_menu.closed.connect(_on_options_menu_closed)
	if exit_confirm_dialog and not exit_confirm_dialog.confirmed.is_connected(_on_exit_confirmed):
		exit_confirm_dialog.confirmed.connect(_on_exit_confirmed)
	if exit_confirm_dialog and not exit_confirm_dialog.canceled.is_connected(_on_exit_canceled):
		exit_confirm_dialog.canceled.connect(_on_exit_canceled)

	_apply_theme()

	animate_transitions = true
	fade_duration_in = 0.22
	fade_duration_out = 0.16
	add_fade_target(dim_rect, 1.0)
	add_fade_target(blur_rect, 1.0)
	add_fade_target(pause_panel, 1.0)
	add_scale_target(pause_panel)

	_set_panel(0)
	_update_gold_label()

	var currency := ManagerLocator.get_currency_manager()
	if currency and not currency.gold_changed.is_connected(_on_gold_changed):
		currency.gold_changed.connect(_on_gold_changed)

# ---------------- OPEN / CLOSE ----------------

func _on_before_open() -> void:
	_set_panel(0)
	_update_gold_label()


func _on_before_close() -> void:
	if options_menu:
		options_menu.close()
	if store_panel and store_panel.is_open:
		store_panel.close()
	if exit_confirm_dialog and exit_confirm_dialog.is_open:
		exit_confirm_dialog.close()

# ---------------- UI ----------------

func _set_panel(i: int) -> void:
	for p in panels:
		p.visible = false

	if i == 1:
		if store_panel and store_panel.is_open:
			store_panel.close()
		if options_menu:
			options_menu.open()
		return

	if i == 2:
		if options_menu:
			options_menu.close()
		if store_panel:
			store_panel.open()
		return

	if options_menu:
		options_menu.close()
	if store_panel and store_panel.is_open:
		store_panel.close()
	panels[i].visible = true


func _on_options_menu_closed() -> void:
	_set_panel(0)


func _on_store_panel_closed() -> void:
	_set_panel(0)

# ---------------- CONNECT ----------------

func _connect() -> void:
	connect_button(options_button, func(): _set_panel(1))
	connect_button(store_button, func(): _set_panel(2))
	connect_button(exit_button, _request_exit)


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
	exit_confirm_dialog.open()


func _emit_exit_requested() -> void:
	exit_requested.emit()

# ---------------- GOLD ----------------

func _update_gold_label() -> void:
	var currency := ManagerLocator.get_currency_manager()
	var current_gold: int = currency.get_gold() if currency else (save_mgr.gold if save_mgr else 0)
	if pause_gold_label:
		pause_gold_label.text = "Oro: %d" % current_gold


func _on_gold_changed(_amount: int) -> void:
	_update_gold_label()

# ---------------- THEME ----------------

func _apply_theme() -> void:
	if pause_panel:
		pause_panel.add_theme_stylebox_override("panel", ThemeManager.build_panel_style(QuestPalette.DUNGEON_CHARCOAL, QuestPalette.GOLD_DARK, 3, 20))
	if pause_gold_label:
		pause_gold_label.add_theme_color_override("font_color", QuestPalette.GOLD)
	if options_button:
		_style_button(options_button)
	if store_button:
		_style_button(store_button)
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
