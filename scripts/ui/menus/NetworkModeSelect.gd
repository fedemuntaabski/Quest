extends Control
class_name NetworkModeSelect

signal host_selected
signal join_selected
signal offline_selected
signal back_pressed

@onready var mode_card: PanelContainer = $CenterContainer/ModeCard
@onready var status_label: Label = $CenterContainer/ModeCard/VBoxContainer/StatusLabel
@onready var host_button: Button = $CenterContainer/ModeCard/VBoxContainer/HostButton
@onready var join_button: Button = $CenterContainer/ModeCard/VBoxContainer/JoinButton
@onready var offline_button: Button = $CenterContainer/ModeCard/VBoxContainer/OfflineButton
@onready var back_button: Button = $CenterContainer/ModeCard/VBoxContainer/BackButton

var _click_sound: AudioStreamPlayer
var _hover_sound: AudioStreamPlayer
var _active_tween: Tween = null


func setup(click_sound: AudioStreamPlayer = null, hover_sound: AudioStreamPlayer = null) -> void:
	_click_sound = click_sound
	_hover_sound = hover_sound


func _ready() -> void:
	_connect_events()
	_refresh_steam_availability()


func _connect_events() -> void:
	for btn: Button in [host_button, join_button, offline_button, back_button]:
		if not btn.mouse_entered.is_connected(_play_hover):
			btn.mouse_entered.connect(_play_hover)

	if not host_button.pressed.is_connected(_on_host_pressed):
		host_button.pressed.connect(_on_host_pressed)
	if not join_button.pressed.is_connected(_on_join_pressed):
		join_button.pressed.connect(_on_join_pressed)
	if not offline_button.pressed.is_connected(_on_offline_pressed):
		offline_button.pressed.connect(_on_offline_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)


func _refresh_steam_availability() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	var available: bool = steam_mgr != null and steam_mgr.is_steam_available()

	host_button.disabled = not available
	join_button.disabled = not available
	status_label.visible = not available
	if not available:
		status_label.text = "Steam no está disponible. Solo modo sin conexión."


func open() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_refresh_steam_availability()
	visible = true

	if mode_card:
		mode_card.pivot_offset = mode_card.size / 2.0
		mode_card.scale = Vector2(0.93, 0.93)
		mode_card.modulate.a = 0.0

		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(mode_card, "scale", Vector2.ONE, 0.25)
		_active_tween.tween_property(mode_card, "modulate:a", 1.0, 0.22)


func close(animate: bool = true) -> void:
	if not visible:
		return

	if not animate:
		visible = false
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	if mode_card:
		mode_card.pivot_offset = mode_card.size / 2.0
		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_active_tween.tween_property(mode_card, "scale", Vector2(0.93, 0.93), 0.18)
		_active_tween.tween_property(mode_card, "modulate:a", 0.0, 0.18)
		_active_tween.chain().tween_callback(func():
			visible = false
		)
	else:
		visible = false


func _on_host_pressed() -> void:
	_play_click()
	host_selected.emit()


func _on_join_pressed() -> void:
	_play_click()
	join_selected.emit()


func _on_offline_pressed() -> void:
	_play_click()
	offline_selected.emit()


func _on_back_pressed() -> void:
	_play_click()
	back_pressed.emit()


func _play_click() -> void:
	if _click_sound and _click_sound.stream:
		_click_sound.play()


func _play_hover() -> void:
	if _hover_sound and _hover_sound.stream and not _hover_sound.playing:
		_hover_sound.play()
