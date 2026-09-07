extends Control
class_name SaveSlotSelector

## SaveSlotSelector — Slot selection UI component.
## Binds to SlotSelection.tscn and communicates with SaveManager.
## Implements responsive hover effects and smooth open/close tweens.

const StatBalance = preload("res://scripts/core/stats/StatBalance.gd")
const EMPTY_SLOT_TEXT := "Ranura vacia.\n\nInicia una nueva aventura en este espacio."

signal slot_selected(slot_id: int)
signal back_pressed

@onready var slot_card: PanelContainer = $CenterContainer/SlotCard
@onready var hover_label: Label = $CenterContainer/SlotCard/HBoxContainer/RightPanel/HoverLabel
@onready var back_button: Button = $CenterContainer/SlotCard/HBoxContainer/LeftPanel/BackButton

@onready var slot_buttons: Array[Button] = [
	$CenterContainer/SlotCard/HBoxContainer/LeftPanel/SlotContainer/SlotRow1/SlotBtn1,
	$CenterContainer/SlotCard/HBoxContainer/LeftPanel/SlotContainer/SlotRow2/SlotBtn2,
	$CenterContainer/SlotCard/HBoxContainer/LeftPanel/SlotContainer/SlotRow3/SlotBtn3
]

@onready var delete_buttons: Array[Button] = [
	$CenterContainer/SlotCard/HBoxContainer/LeftPanel/SlotContainer/SlotRow1/Delete1,
	$CenterContainer/SlotCard/HBoxContainer/LeftPanel/SlotContainer/SlotRow2/Delete2,
	$CenterContainer/SlotCard/HBoxContainer/LeftPanel/SlotContainer/SlotRow3/Delete3
]

var _click_sound: AudioStreamPlayer
var _hover_sound: AudioStreamPlayer
var _button_tweens: Dictionary = {}
var _active_tween: Tween = null
var _info_tween: Tween = null


func setup(click_sound: AudioStreamPlayer = null, hover_sound: AudioStreamPlayer = null) -> void:
	_click_sound = click_sound
	_hover_sound = hover_sound


func _ready() -> void:
	_connect_events()
	refresh()


func _connect_events() -> void:
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
		_register_button_hover(back_button)

	for i in range(slot_buttons.size()):
		var slot_id := i + 1
		var btn := slot_buttons[i]
		var del_btn := delete_buttons[i]

		if not btn.pressed.is_connected(_on_slot_clicked.bind(slot_id)):
			btn.pressed.connect(_on_slot_clicked.bind(slot_id))
		if not btn.mouse_entered.is_connected(_on_slot_hovered.bind(slot_id)):
			btn.mouse_entered.connect(_on_slot_hovered.bind(slot_id))
		if not btn.focus_entered.is_connected(_on_slot_hovered.bind(slot_id)):
			btn.focus_entered.connect(_on_slot_hovered.bind(slot_id))

		_register_button_hover(btn)

		if not del_btn.pressed.is_connected(_on_delete_clicked.bind(slot_id)):
			del_btn.pressed.connect(_on_delete_clicked.bind(slot_id))
		_register_button_hover(del_btn)


func _register_button_hover(btn: Button) -> void:
	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_btn_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))


func _on_btn_mouse_entered(btn: Button) -> void:
	_play_hover()
	_animate_button_scale(btn, 1.04)


func _on_btn_mouse_exited(btn: Button) -> void:
	_animate_button_scale(btn, 1.0)


func _animate_button_scale(btn: Button, target_scale: float) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	var cur_tween = _button_tweens.get(btn) as Tween
	if cur_tween and cur_tween.is_valid():
		cur_tween.kill()
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_button_tweens[btn] = t
	t.tween_property(btn, "scale", Vector2(target_scale, target_scale), 0.16)


func refresh() -> void:
	var save_mgr := ManagerLocator.get_save_manager()

	for i in range(slot_buttons.size()):
		var slot_id := i + 1
		var btn := slot_buttons[i]
		var del_btn := delete_buttons[i]

		var has_save := bool(save_mgr and save_mgr.has_save(slot_id))
		if has_save:
			btn.text = "RANURA %d (GUARDADA)" % slot_id
			del_btn.disabled = false
			del_btn.modulate.a = 1.0
		else:
			btn.text = "RANURA %d (VACIA)" % slot_id
			del_btn.disabled = true
			del_btn.modulate.a = 0.45


func open() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	refresh()
	visible = true

	if slot_card:
		slot_card.pivot_offset = slot_card.size / 2.0
		slot_card.scale = Vector2(0.93, 0.93)
		slot_card.modulate.a = 0.0

		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(slot_card, "scale", Vector2.ONE, 0.25)
		_active_tween.tween_property(slot_card, "modulate:a", 1.0, 0.22)


func close(animate: bool = true) -> void:
	if not visible:
		return

	if not animate:
		visible = false
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	if slot_card:
		slot_card.pivot_offset = slot_card.size / 2.0
		_active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_active_tween.tween_property(slot_card, "scale", Vector2(0.93, 0.93), 0.18)
		_active_tween.tween_property(slot_card, "modulate:a", 0.0, 0.18)
		_active_tween.chain().tween_callback(func():
			visible = false
		)
	else:
		visible = false


# ---------------- EVENTS ----------------

func _on_slot_clicked(slot_id: int) -> void:
	_play_click()
	slot_selected.emit(slot_id)


func _on_delete_clicked(slot_id: int) -> void:
	_play_click()
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.delete_save(slot_id)
	_set_info_text("Ranura %d eliminada." % slot_id)
	refresh()


func _on_back_pressed() -> void:
	_play_click()
	back_pressed.emit()


func _on_slot_hovered(slot_id: int) -> void:
	var summary := _get_slot_summary(slot_id)
	_set_info_text(summary)


func _set_info_text(new_text: String) -> void:
	if hover_label == null:
		return

	if _info_tween and _info_tween.is_valid():
		_info_tween.kill()

	_info_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_info_tween.tween_property(hover_label, "modulate:a", 0.3, 0.08)
	_info_tween.chain().tween_callback(func():
		hover_label.text = new_text
	)
	_info_tween.chain().tween_property(hover_label, "modulate:a", 1.0, 0.12)


func _play_click() -> void:
	if _click_sound and _click_sound.stream:
		_click_sound.play()


func _play_hover() -> void:
	if _hover_sound and _hover_sound.stream and not _hover_sound.playing:
		_hover_sound.play()


func _get_slot_summary(slot_id: int) -> String:
	var save_mgr := ManagerLocator.get_save_manager()
	if not save_mgr or not save_mgr.has_save(slot_id):
		return EMPTY_SLOT_TEXT

	var cfg := ConfigFile.new()
	var err := cfg.load(save_mgr.get_save_path(slot_id))
	if err != OK:
		return "No se pudieron leer los datos de guardado."

	var gold = cfg.get_value("save_data", "gold", 0)
	var contracts = cfg.get_value("save_data", "run_cycle", cfg.get_value("save_data", "contracts_completed", 0))
	var s_hp = cfg.get_value("save_data", "base_hp", StatBalance.PLAYER_BASE_HP)
	var s_str = cfg.get_value("save_data", "base_str", 0)
	var s_mag = cfg.get_value("save_data", "base_mag", 0)
	var s_dex = cfg.get_value("save_data", "base_dex", 0)

	var max_stat_name := "Fuerza"
	var max_stat_val = s_str

	if s_mag > max_stat_val:
		max_stat_name = "Magia"
		max_stat_val = s_mag

	if s_dex > max_stat_val:
		max_stat_name = "Destreza"
		max_stat_val = s_dex

	return (
		"DATOS DE LA RANURA %d:\n\n" +
		"• Oro acumulado: %d\n" +
		"• Ciclo de contratos: %d\n" +
		"• Vida base: %d/%d\n" +
		"• Atributo principal: %s (+%d)\n\n" +
		"Haz clic para continuar la aventura."
	) % [
		slot_id,
		gold,
		contracts,
		s_hp,
		StatBalance.PLAYER_MAX_HP,
		max_stat_name,
		max_stat_val
	]
