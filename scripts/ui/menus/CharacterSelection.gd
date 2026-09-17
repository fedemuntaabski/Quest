extends Control
class_name CharacterSelection

## CharacterSelection — single-player hero-pick screen shown for a fresh save slot.
## MainMenuFlow opens this between slot selection and the game/waiting-room scene change.

signal character_confirmed(character_id: String)
signal back_pressed

const CharacterDatabase = preload("res://scripts/core/stats/CharacterDatabase.gd")
const CardOptionScene := preload("res://scenes/CharacterCardOption.tscn")

@onready var selection_card: PanelContainer = $CenterContainer/SelectionCard
@onready var cards_container: GridContainer = $CenterContainer/SelectionCard/VBoxContainer/ContentRow/CardsContainer
@onready var preview_placeholder: PanelContainer = $CenterContainer/SelectionCard/VBoxContainer/ContentRow/CharacterPreviewPlaceholder
@onready var confirm_button: Button = $CenterContainer/SelectionCard/VBoxContainer/ConfirmButton
@onready var back_button: Button = $CenterContainer/SelectionCard/VBoxContainer/BackButton

var _click_sound: AudioStreamPlayer
var _hover_sound: AudioStreamPlayer
var _active_tween: Tween = null
var _is_animating_open: bool = false
var _selected_id: String = ""
var _cards: Dictionary = {}


func setup(click_sound: AudioStreamPlayer = null, hover_sound: AudioStreamPlayer = null) -> void:
	_click_sound = click_sound
	_hover_sound = hover_sound


func _ready() -> void:
	_build_cards()
	_connect_events()
	if preview_placeholder:
		preview_placeholder.add_theme_stylebox_override("panel", ThemeManager.build_slot_icon_style())


func _build_cards() -> void:
	for data in CharacterDatabase.get_all():
		var card := CardOptionScene.instantiate()
		cards_container.add_child(card)
		card.setup(data)
		card.selected.connect(_on_card_selected)
		_cards[data.character_id] = card


func _connect_events() -> void:
	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	for btn: Button in [confirm_button, back_button]:
		if not btn.mouse_entered.is_connected(_play_hover):
			btn.mouse_entered.connect(_play_hover)

	confirm_button.disabled = true


func _on_card_selected(character_id: String) -> void:
	_selected_id = character_id
	for id in _cards.keys():
		_cards[id].set_selected(id == character_id)
	confirm_button.disabled = false
	_play_click()


func _on_confirm_pressed() -> void:
	if _selected_id == "":
		return
	_play_click()
	character_confirmed.emit(_selected_id)


func _on_back_pressed() -> void:
	_play_click()
	back_pressed.emit()


func open() -> void:
	if visible and _is_animating_open:
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	visible = true
	_is_animating_open = true
	_set_transition_buttons_disabled(true)

	var scale_targets: Array[CanvasItem] = []
	if selection_card:
		scale_targets.append(selection_card)

	_active_tween = MenuTransitionFX.play_entrance(
		self,
		[{"node": self, "max_alpha": 1.0}],
		scale_targets,
		0.28, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2(0.93, 0.93)
	)
	if _active_tween != null:
		await _active_tween.finished

	_set_transition_buttons_disabled(false)


func close(animate: bool = true) -> void:
	if not visible:
		return

	_is_animating_open = false

	if not animate:
		if _active_tween and _active_tween.is_valid():
			_active_tween.kill()
		visible = false
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_set_transition_buttons_disabled(true)

	var scale_targets: Array[CanvasItem] = []
	if selection_card:
		scale_targets.append(selection_card)

	_active_tween = MenuTransitionFX.play_exit(
		self,
		[{"node": self, "max_alpha": 1.0}],
		scale_targets,
		0.28, Vector2(0.93, 0.93),
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
	)
	if _active_tween != null:
		await _active_tween.finished

	visible = false


func _set_transition_buttons_disabled(is_disabled: bool) -> void:
	if back_button:
		back_button.disabled = is_disabled
	if confirm_button:
		confirm_button.disabled = is_disabled if is_disabled else (_selected_id == "")


func _play_click() -> void:
	if _click_sound and _click_sound.stream:
		_click_sound.play()


func _play_hover() -> void:
	if _hover_sound and _hover_sound.stream and not _hover_sound.playing:
		_hover_sound.play()
