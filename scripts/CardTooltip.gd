extends Control
class_name CardTooltip

@onready var name_label: Label = $Panel/VBox/Name
@onready var desc_label: Label = $Panel/VBox/Description
@onready var stats_label: Label = $Panel/VBox/Stats

func set_card(data: Dictionary) -> void:
	if data == null or data.is_empty():
		visible = false
		return

	visible = true
	name_label.text = str(data.get("name", "Card"))
	desc_label.text = str(data.get("description", ""))

	var range_val := int(data.get("range", 0))
	var cd := int(data.get("cooldown", 0))
	var stat := str(data.get("stat", ""))
	stats_label.text = "Range: %d | CD: %d | Stat: %s" % [range_val, cd, stat]
