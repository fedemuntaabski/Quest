extends Control
class_name CardTooltip

@onready var name_label: Label = $Panel/VBox/Name
@onready var desc_label: Label = $Panel/VBox/Description
@onready var details_label: Label = $Panel/VBox/Details

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

	name_label.text = str(data.get("name", "Card"))
	desc_label.text = str(data.get("description", ""))

	var range_val := int(data.get("range", 0))
	var cd := int(data.get("cooldown", 0))
	var cd_remaining := int(data.get("cooldown_remaining", 0))
	var stat := str(data.get("scaling_stat", data.get("stat", "")))
	var scaling := float(data.get("damage_scaling", 1.0))
	var available : Variant = data.get("is_usable", true) != false
	var state_text := "Disponible" if available and cd_remaining <= 0 else "En enfriamiento (%d)" % cd_remaining
	if not available and cd_remaining <= 0:
		state_text = str(data.get("state", "Bloqueada")).capitalize()

	# Build details text with short labels to keep tooltip compact
	details_label.text = "R: %d  CD: %d\n%s x%.2f  |  %s" % [
		range_val,
		cd,
		StatTypes.get_label(stat),
		scaling,
		state_text
	]
