extends CanvasLayer
class_name PauseMenu

signal exit_requested

const DEFAULT_EXIT_MESSAGE := "¿Estás seguro de salir? Se perderán los datos de esta partida."

@export var player_stats: PlayerStats
@export var confirm_exit_on_run: bool = true

var is_open: bool = false
var animate_transitions: bool = true
var _tween: Tween

@onready var pause_panel: Panel = %PausePanel
@onready var blur_rect: ColorRect = %BlurRect
@onready var dim_rect: ColorRect = %DimRect
@onready var options_menu: OptionsMenu = %OptionsMenu
@onready var bestiary_panel: BestiaryPanel = %BestiaryPanel
@onready var hover_sound: AudioStreamPlayer = %HoverSound
var exit_confirm_dialog: ConfirmationDialog

@onready var options_button: Button = %OptionsButton
@onready var bestiary_button: Button = %BestiaryButton
@onready var exit_button: Button = %ExitButton

@onready var panels: Array[Control] = [pause_panel, options_menu, bestiary_panel]

# ---------------- INIT ----------------

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if player_stats == null:
		player_stats = ManagerLocator.get_player_stats()

	%ClickSound.stream = load("res://assets/audio/click.mp3")  # OptionsMenu plays it
	hover_sound.stream = load("res://assets/audio/hover.mp3")

	_connect()
	_build_exit_dialog()

	if options_menu and not options_menu.closed.is_connected(_on_options_menu_closed):
		options_menu.closed.connect(_on_options_menu_closed)
	if bestiary_panel and not bestiary_panel.closed.is_connected(_on_options_menu_closed):
		bestiary_panel.closed.connect(_on_options_menu_closed)

	_apply_theme()
	_fit_panel_to_content()
	_set_panel(0)


## Godot's ConfirmationDialog in the menu frame (same as the main menu's dialogs).
func _build_exit_dialog() -> void:
	exit_confirm_dialog = ConfirmationDialog.new()
	exit_confirm_dialog.name = "ExitConfirmDialog"
	exit_confirm_dialog.title = "Salir"
	exit_confirm_dialog.ok_button_text = "OK"
	exit_confirm_dialog.cancel_button_text = "Cancelar"
	exit_confirm_dialog.dialog_autowrap = true
	exit_confirm_dialog.min_size = Vector2i(520, 0)
	exit_confirm_dialog.confirmed.connect(_emit_exit_requested)
	exit_confirm_dialog.canceled.connect(_set_panel.bind(0))
	UiStyles.style_menu_dialog(exit_confirm_dialog)
	UiStyles.style_menu_button(exit_confirm_dialog.get_ok_button(), true)  # leaving = the red rim, like SALIR
	add_child(exit_confirm_dialog)

# ---------------- OPEN / CLOSE ----------------

func open() -> void:
	if is_open:
		return
	is_open = true
	_set_panel(0)
	if options_button:
		options_button.grab_focus.call_deferred()  # gamepad / keyboard navigation
	visible = true
	if not Net.is_online():  # coop-12: online the world keeps running
		var gsm := ManagerLocator.get_game_state_manager()
		if gsm:
			gsm.request_pause()
	if animate_transitions:
		_kill_tween()
		_tween = MenuTransitionFX.play_entrance(self, _fade_targets(), [pause_panel], 0.22, Tween.TRANS_BACK, Tween.EASE_OUT, Vector2(0.92, 0.92))


func close() -> void:
	if not is_open:
		return
	if controls_help:
		controls_help.hide()
	if options_menu:
		options_menu.close()
	if bestiary_panel:
		bestiary_panel.close()
	if exit_confirm_dialog:
		exit_confirm_dialog.hide()
	if animate_transitions:
		_kill_tween()
		_tween = MenuTransitionFX.play_exit(self, _fade_targets(), [pause_panel], 0.16, Vector2(0.94, 0.94))
		if _tween:
			await _tween.finished
	visible = false
	var gsm := ManagerLocator.get_game_state_manager()
	if gsm:
		gsm.request_resume()
	is_open = false


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _fade_targets() -> Array[Dictionary]:
	return [{"node": dim_rect, "max_alpha": 1.0}, {"node": blur_rect, "max_alpha": 1.0}, {"node": pause_panel, "max_alpha": 1.0}]


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func connect_button(btn: Button, on_press: Callable) -> void:
	btn.pressed.connect(on_press)
	btn.mouse_entered.connect(hover_sound.play)

# ---------------- UI ----------------

func _set_panel(i: int) -> void:
	for p in panels:
		p.visible = false

	if i == 1:
		if options_menu:
			options_menu.open()
		return
	if i == 2:
		if bestiary_panel:
			bestiary_panel.open()
		return

	if options_menu:
		options_menu.close()
	if bestiary_panel and bestiary_panel.is_open:
		bestiary_panel.is_open = false
	panels[i].visible = true


func _on_options_menu_closed() -> void:
	_set_panel(0)


# ---------------- CONNECT ----------------

func _connect() -> void:
	connect_button(options_button, func(): _set_panel(1))
	connect_button(bestiary_button, func(): _set_panel(2))
	connect_button(exit_button, _request_exit)
	_add_controls_button()


## calidad-13: "Controles" opens the shortcut list (ControlsHelp), next to Bestiario.
var controls_button: Button
var controls_help: ControlsHelp


func _add_controls_button() -> void:
	if bestiary_button == null:
		return
	controls_button = Button.new()
	controls_button.name = "ControlsButton"
	controls_button.text = "CONTROLES"
	controls_button.custom_minimum_size = bestiary_button.custom_minimum_size
	controls_button.size_flags_horizontal = bestiary_button.size_flags_horizontal
	controls_button.add_theme_font_override("font", bestiary_button.get_theme_font("font"))
	controls_button.add_theme_font_size_override("font_size", bestiary_button.get_theme_font_size("font_size"))
	bestiary_button.add_sibling(controls_button)
	_style_button(controls_button)
	controls_help = ControlsHelp.new()
	controls_help.name = "ControlsHelp"
	add_child(controls_help)
	connect_button(controls_button, controls_help.open)


func _request_exit() -> void:
	if not confirm_exit_on_run:
		exit_requested.emit()
		return
	exit_confirm_dialog.dialog_text = exit_message()
	exit_confirm_dialog.popup_centered()
	exit_confirm_dialog.get_ok_button().grab_focus()


## guardado-19: what leaving costs. Offline from floor 2 the run is saved at the
## floor's start; online and on floor 1 nothing is kept.
func exit_message() -> String:
	var save_mgr := ManagerLocator.get_save_manager()
	var session := ManagerLocator.get_game_session()
	if session and session.tutorial:
		return "¿Salir del tutorial?"
	if Net.is_online():
		return "¿Salir al menú? El co-op no guarda la partida: se perderá."
	var run: Dictionary = save_mgr.get_saved_run() if save_mgr else {}
	if not run.is_empty():
		return "¿Salir al menú? Se pierde el progreso de este piso: al continuar, la partida se retoma desde el inicio del piso %d." % int(run["floor"])
	return DEFAULT_EXIT_MESSAGE


func _emit_exit_requested() -> void:
	exit_requested.emit()

# ---------------- THEME ----------------

## menu-33: same frame and plaques as the main menu (UiStyles).
func _apply_theme() -> void:
	if pause_panel:
		UiStyles.style_menu_frame(pause_panel)
	if options_button:
		_style_button(options_button)
	if bestiary_button:
		_style_button(bestiary_button)
	if exit_button:
		_style_button(exit_button, true)


## menu-34: PausePanel is a plain Panel (fixed 560x500 in the .tscn) with PauseVBox centred by
## anchors; at text scale 1.5 the box outgrew it (SALIR hung below the frame). The panel now
## grows to the box's minimum size plus the .tscn margins, and follows later changes.
var _panel_base_size := Vector2.ZERO
var _panel_margin := Vector2.ZERO


func _fit_panel_to_content() -> void:
	var box := pause_panel.get_node_or_null("PauseVBox") as Control if pause_panel else null
	if box == null:
		return
	_panel_base_size = pause_panel.custom_minimum_size
	_panel_margin = _panel_base_size - (box.get_offset(SIDE_RIGHT) - box.get_offset(SIDE_LEFT)) * Vector2.RIGHT \
		- (box.get_offset(SIDE_BOTTOM) - box.get_offset(SIDE_TOP)) * Vector2.DOWN
	if not box.minimum_size_changed.is_connected(_on_pause_box_resized):
		box.minimum_size_changed.connect(_on_pause_box_resized)
	_on_pause_box_resized()


func _on_pause_box_resized() -> void:
	var box := pause_panel.get_node("PauseVBox") as Control
	pause_panel.custom_minimum_size = _panel_base_size.max(box.get_combined_minimum_size() + _panel_margin)


func _style_button(button: Button, danger: bool = false) -> void:
	UiStyles.style_menu_button(button, danger)
