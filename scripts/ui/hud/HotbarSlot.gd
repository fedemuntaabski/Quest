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

var _card_data: CardDisplayData = null  # Now typed instead of Dictionary
var _is_selected: bool = false
var tooltip_host: CardTooltip = null

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

func set_card(data: CardDisplayData) -> void:
	_card_data = data
	_update_ui()

func set_tooltip_host(host: CardTooltip) -> void:
	tooltip_host = host

func set_selected(selected: bool) -> void:
	_is_selected = selected
	if selection_border:
		selection_border.visible = selected
	# Restore full opacity when deselected
	if not selected:
		modulate = Color(0.95, 0.95, 0.92, 1.0)
	# subtle scale feedback
	if selected:
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(1.04, 1.04), 0.12)
	else:
		var t2 = create_tween()
		t2.tween_property(self, "scale", Vector2(1, 1), 0.12)

func set_usable(usable: bool) -> void:
	modulate = Color(0.95, 0.95, 0.92, 1.0) if usable else Color(0.82, 0.64, 0.64, 0.92)
	if state_label:
		state_label.visible = false
		state_label.text = ""
	# Color-code borders when blocked to provide a stronger visual cue
	if not usable:
		if hover_border:
			hover_border.modulate = QuestPalette.BLOOD_LIGHT
		if selection_border:
			selection_border.modulate = QuestPalette.BLOOD_LIGHT
	else:
		if hover_border:
			hover_border.modulate = QuestPalette.PARCHMENT_LIGHT
		if selection_border:
			selection_border.modulate = QuestPalette.PARCHMENT_LIGHT

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
	if _card_data == null:
		_clear_display()
		return
	
	# Use typed properties directly (no .get() fallback needed)
	if name_label:
		name_label.text = _card_data.display_name

	if state_label:
		state_label.visible = false
		state_label.text = ""

	if icon:
		icon.texture = _card_data.icon

	set_cooldown(_card_data.cooldown_remaining)
	# Visual usability: use typed property
	set_usable(_card_data.is_usable)
	# Show playability reason if blocked
	if not _card_data.is_usable:
		set_state_label(_card_data.playability_reason)
	else:
		set_state_label("")

func _clear_display() -> void:
	if name_label:
		name_label.text = "-"
	if icon:
		icon.texture = null
	if state_label:
		state_label.visible = false
		state_label.text = ""
	if cooldown_label:
		cooldown_label.visible = false
		cooldown_label.text = ""
	if cooldown_overlay:
		cooldown_overlay.visible = false

func _on_mouse_entered() -> void:
	if hover_border:
		hover_border.visible = true
	# hover scale
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.02, 1.02), 0.08)
	if tooltip_host and _card_data:
		# Pass CardDisplayData directly instead of dictionary
		tooltip_host.request_show(_card_data)

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
		tooltip_host.request_hide()
