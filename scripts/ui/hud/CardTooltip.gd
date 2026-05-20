extends Control
class_name CardTooltip

@onready var name_label: Label = $Panel/VBox/Name
@onready var desc_label: Label = $Panel/VBox/Description
@onready var details_label: Label = $Panel/VBox/Details

var _tooltip_timer: Timer = null
var _pending_card_data: CardDisplayData = null  # Now typed instead of Dictionary
const TOOLTIP_DEBOUNCE_TIME := 0.08

func _ready() -> void:
	# Create an internal timer to debounce rapid hover switches
	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.wait_time = TOOLTIP_DEBOUNCE_TIME
	_tooltip_timer.connect("timeout", Callable(self, "_on_tooltip_timer_timeout"))
	add_child(_tooltip_timer)

func request_show(data: CardDisplayData) -> void:
	# Called by HotbarSlot to request a tooltip show. Debounced.
	_pending_card_data = data
	if _tooltip_timer.time_left > 0.0:
		_tooltip_timer.stop()
	_tooltip_timer.start()

func request_hide() -> void:
	# Cancel pending show and hide any visible tooltip
	_pending_card_data = null
	if _tooltip_timer and _tooltip_timer.time_left > 0.0:
		_tooltip_timer.stop()
	visible = false
	set_card(null)

func _on_tooltip_timer_timeout() -> void:
	if _pending_card_data == null:
		return
	set_card(_pending_card_data)
	_pending_card_data = null


func set_card(data: CardDisplayData) -> void:
	if data == null:
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
	
	# Use typed properties directly (no .get() fallback needed)
	name_label.text = data.display_name
	desc_label.text = data.description

	# Use adapter formatter for consistent display
	var stats_summary := CardPresentationAdapter.get_stats_summary(data)
	var cooldown_text := CardPresentationAdapter.get_cooldown_text(data)
	details_label.text = "%s | %s" % [stats_summary, cooldown_text]
	
	# Show playability reason if card is blocked
	var playability_text := CardPresentationAdapter.get_playability_text(data)
	if not playability_text.is_empty():
		details_label.text += "\n(%s)" % playability_text
