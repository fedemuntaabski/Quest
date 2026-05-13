extends Control
class_name CardTooltip

@onready var name_label: Label = $Panel/VBox/Name
@onready var desc_label: Label = $Panel/VBox/Description
@onready var details_label: Label = $Panel/VBox/Details

func set_card(data: Dictionary) -> void:
	if data == null or data.is_empty():
		visible = false
		return

	visible = true
	name_label.text = str(data.get("name", "Card"))
	desc_label.text = str(data.get("description", ""))

	var range_val := int(data.get("range", 0))
	var cd := int(data.get("cooldown", 0))
	var cd_remaining := int(data.get("cooldown_remaining", 0))
	var stat := str(data.get("scaling_stat", data.get("stat", "")))
	var scaling := float(data.get("damage_scaling", 1.0))
	var available := bool(data.get("is_usable", true))
	var state_text := "Disponible" if available and cd_remaining <= 0 else "En enfriamiento (%d)" % cd_remaining
	if not available and cd_remaining <= 0:
		state_text = str(data.get("state", "Bloqueada")).capitalize()

	details_label.text = "Alcance: %d\nEnfriamiento: %d\nAtributo/escala: %s x%.2f\nEstado: %s" % [
		range_val,
		cd,
		StatTypes.get_label(stat),
		scaling,
		state_text
	]
