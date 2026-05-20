extends PanelContainer
class_name HotbarSlot

signal slot_pressed(index: int)

@export var slot_index: int = 0

@onready var icon: TextureRect = $VBox/Icon
@onready var name_label: Label = $VBox/Name
@onready var cooldown_label: Label = $VBox/Cooldown
@onready var state_label: Label = $VBox/State
@onready var key_label: Label = $VBox/KeyLabel
@onready var selection_border: Panel = $SelectionBorder
@onready var hover_border: Panel = $HoverBorder
@onready var cooldown_overlay: ColorRect = $CooldownOverlay

var _card_data: Dictionary = {}
var _is_selected: bool = false
var tooltip_host: HUDController = null

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Allow hover/selection visuals while game is paused (scene-controlled)
	if key_label:
		key_label.text = str(slot_index + 1)
	_update_ui()
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_pressed.emit(slot_index)
		accept_event()

func set_card(data: Dictionary) -> void:
	_card_data = data if data != null else {}
	_update_ui()

func set_tooltip_host(host: HUDController) -> void:
	tooltip_host = host

func set_selected(selected: bool) -> void:
	_is_selected = selected
	if selection_border:
		selection_border.visible = selected
	# Restore full opacity when deselected
	if not selected:
		modulate = Color(1, 1, 1, 1)
	# subtle scale feedback
	if selected:
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(1.04, 1.04), 0.12)
	else:
		var t2 = create_tween()
		t2.tween_property(self, "scale", Vector2(1, 1), 0.12)

func set_usable(usable: bool) -> void:
	modulate = Color(1, 1, 1, 1) if usable else Color(0.8, 0.6, 0.6, 0.9)
	if state_label:
		state_label.visible = false
		state_label.text = ""
	# Color-code borders when blocked to provide a stronger visual cue
	if not usable:
		if hover_border:
			hover_border.modulate = Color(1.0, 0.45, 0.45)
		if selection_border:
			selection_border.modulate = Color(1.0, 0.45, 0.45)
	else:
		if hover_border:
			hover_border.modulate = Color(1, 1, 1, 1)
		if selection_border:
			selection_border.modulate = Color(1, 1, 1, 1)

func set_state_label(_state: String) -> void:
	if state_label == null:
		return
	if _state == null or str(_state) == "":
		state_label.visible = false
		state_label.text = ""
		return
	state_label.visible = true
	state_label.text = str(_state)

func set_cooldown(turns_left: int) -> void:
	if turns_left > 0:
		cooldown_label.text = "CD: %d" % turns_left
		cooldown_label.visible = true
	else:
		cooldown_label.text = ""
		cooldown_label.visible = false
	if cooldown_overlay:
		cooldown_overlay.visible = turns_left > 0

func _update_ui() -> void:
	if name_label:
		name_label.text = _card_data.get("name", "-")

	if state_label:
		state_label.visible = false
		state_label.text = ""

	if icon:
		var tex: Texture2D = _card_data.get("icon", null)
		icon.texture = tex

	set_cooldown(int(_card_data.get("cooldown_remaining", 0)))
	# Visual usability: prefer explicit full_playable if present, otherwise fall back to legacy is_usable
	var usable := bool(_card_data.get("full_playable")) if _card_data.has("full_playable") else bool(_card_data.get("is_usable", true))
	set_usable(usable)
	# Show playability reason if blocked
	if not usable:
		var reason := str(_card_data.get("playability_reason_readable", _card_data.get("playability_reason", "")))
		set_state_label(reason)
	else:
		set_state_label("")

func _on_mouse_entered() -> void:
	if hover_border:
		hover_border.visible = true
	# hover scale
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.02, 1.02), 0.08)
	if tooltip_host:
		tooltip_host.show_card_tooltip(_card_data)

func _on_mouse_exited() -> void:
	if hover_border:
		hover_border.visible = false
	# restore scale (respect selection state)
	var target_scale := Vector2(1, 1)
	if _is_selected:
		target_scale = Vector2(1.04, 1.04)
	var t = create_tween()
	t.tween_property(self, "scale", target_scale, 0.08)
	if tooltip_host:
		tooltip_host.hide_card_tooltip()
