extends Control
class_name CardTooltip

const CardViewModel = preload("res://scripts/ui/hud/CardViewModel.gd")

@onready var name_label: Label = $Panel/VBox/Name
@onready var desc_label: Label = $Panel/VBox/Description
@onready var details_label: Label = $Panel/VBox/Details

var _tooltip_timer: Timer = null
var _pending_card_data: Dictionary = {}
const TOOLTIP_DEBOUNCE_TIME := 0.08

func _ready() -> void:
	# Create an internal timer to debounce rapid hover switches
	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.wait_time = TOOLTIP_DEBOUNCE_TIME
	_tooltip_timer.connect("timeout", Callable(self, "_on_tooltip_timer_timeout"))
	add_child(_tooltip_timer)

func request_show(data: Dictionary) -> void:
	# Called by HUDController or HotbarSlot to request a tooltip show. Debounced.
	_pending_card_data = data if data != null else {}
	if _tooltip_timer.time_left > 0.0:
		_tooltip_timer.stop()
	_tooltip_timer.start()

func request_hide() -> void:
	# Cancel pending show and hide any visible tooltip
	_pending_card_data = {}
	if _tooltip_timer and _tooltip_timer.time_left > 0.0:
		_tooltip_timer.stop()
	visible = false
	set_card({})

func _on_tooltip_timer_timeout() -> void:
	if _pending_card_data.size() == 0:
		return
	set_card(_pending_card_data)
	_pending_card_data = {}


func set_card(data: Dictionary) -> void:
	if data == null or data.is_empty():
		# Clear contents to avoid ghost text when hidden
		visible = false
		name_label.text = ""
		desc_label.text = ""
		details_label.text = ""
		return

	visible = true
	# Ensure labels are reset before populating
	name_label.text = ""
	desc_label.text = ""
	details_label.text = ""
	var view := CardViewModel.normalize_from_payload(data)

	name_label.text = view.get("display_name", "Card")
	desc_label.text = view.get("description", "")

	# Use normalized summaries for compact tooltip
	var stats := str(view.get("stats_summary", ""))
	var state_text := str(view.get("state_text", ""))
	details_label.text = "%s\n%s" % [stats, state_text]
	var readable := str(view.get("playability_reason_readable", ""))
	if readable != "":
		details_label.text += "\n(%s)" % readable
