extends Control
class_name CardTooltip

@onready var name_label: Label = $Panel/VBox/Name
@onready var desc_label: Label = $Panel/VBox/Description
@onready var details_label: Label = $Panel/VBox/Details

const TOOLTIP_DEBOUNCE_TIME := 0.08

var _tooltip_timer: Timer
var _pending_card_data: CardDisplayData = null
var _active_data: CardDisplayData = null


func _ready() -> void:
	visible = false

	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.wait_time = TOOLTIP_DEBOUNCE_TIME
	_tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	add_child(_tooltip_timer)


# -------------------------
# Public API
# -------------------------

func request_show(data: CardDisplayData) -> void:
	if data == null:
		request_hide()
		return

	_pending_card_data = data

	# Reinicia debounce de forma limpia
	if _tooltip_timer.is_stopped():
		_tooltip_timer.start()
	else:
		_tooltip_timer.stop()
		_tooltip_timer.start()


func request_hide() -> void:
	_pending_card_data = null
	_active_data = null

	if _tooltip_timer and not _tooltip_timer.is_stopped():
		_tooltip_timer.stop()

	_clear()
	visible = false


# -------------------------
# Internal logic
# -------------------------

func _on_tooltip_timer_timeout() -> void:
	if _pending_card_data == null:
		return

	_active_data = _pending_card_data
	_pending_card_data = null

	_set_card(_active_data)


func _set_card(data: CardDisplayData) -> void:
	if data == null:
		request_hide()
		return

	visible = true

	name_label.text = data.display_name
	desc_label.text = data.description

	var stats_summary := CardPresentationAdapter.get_stats_summary(data)
	var cooldown_text := CardPresentationAdapter.get_cooldown_text(data)

	details_label.text = "%s | %s" % [stats_summary, cooldown_text]

	var playability_text := CardPresentationAdapter.get_playability_text(data)
	if not playability_text.is_empty():
		details_label.text += "\n(%s)" % playability_text


func _clear() -> void:
	if name_label:
		name_label.text = ""
	if desc_label:
		desc_label.text = ""
	if details_label:
		details_label.text = ""