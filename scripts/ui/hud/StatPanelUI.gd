extends HBoxContainer
class_name StatPanelUI

const HP_FORMAT := "%d/%d"
const RESOURCE_FORMAT := "%d"

@onready var label_hp: Label = $ChipHP/LabelHP

@onready var label_industry: Label = $ChipIndustry/LabelIndustry
@onready var label_food: Label = $ChipFood/LabelFood
@onready var label_science: Label = $ChipScience/LabelScience
@onready var label_dust: Label = $ChipDust/LabelDust


func update_stats(stats: CharacterStats) -> void:
	if stats == null:
		return

	update_hp(
		stats.current_hp,
		stats.max_hp
	)


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


func _set_label_text(
	label: Label,
	value: String
) -> void:

	if label == null:
		return

	label.text = value
