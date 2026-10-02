extends HBoxContainer
class_name StatPanelUI

## Top-left resource bar: per resource an icon, the amount and the per-turn
## gain (ResourceManager.get_turn_yield). HP moved to HeroPortrait in session 6;
## update_hp stays as a no-op-if-missing for old callers.

const HP_FORMAT := "%d/%d"
const RESOURCE_FORMAT := "%d"
const GAIN_FORMAT := "+%d"

@onready var label_hp: Label = get_node_or_null("ChipHP/LabelHP")

@onready var label_industry: Label = $ChipIndustry/LabelIndustry
@onready var label_food: Label = $ChipFood/LabelFood
@onready var label_science: Label = $ChipScience/LabelScience
@onready var label_dust: Label = $ChipDust/LabelDust

@onready var gain_labels := {
	"industry": $ChipIndustry/GainIndustry as Label,
	"food": $ChipFood/GainFood as Label,
	"science": $ChipScience/GainScience as Label,
	"dust": $ChipDust/GainDust as Label,
}


func update_hp(
	current_hp: int,
	max_hp: int
) -> void:

	_set_label_text(
		label_hp,
		HP_FORMAT % [current_hp, max_hp]
	)


func update_resource(key: String, amount: int) -> void:
	var text := RESOURCE_FORMAT % amount

	match key:
		"industry":
			_set_label_text(label_industry, text)
		"food":
			_set_label_text(label_food, text)
		"science":
			_set_label_text(label_science, text)
		"dust":
			_set_label_text(label_dust, text)


## Hidden when the resource has no per-turn income (dust today).
func update_gain(key: String, amount: int) -> void:
	var label: Label = gain_labels.get(key)
	if label == null:
		return
	label.text = GAIN_FORMAT % amount
	label.visible = amount > 0


func _set_label_text(
	label: Label,
	value: String
) -> void:

	if label == null:
		return

	label.text = value
