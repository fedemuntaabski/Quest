extends Control
class_name StatPanelUI

const HP_FORMAT := "HP %d/%d"
const AP_FORMAT := "AP %d/%d"

@onready var label_hp: Label = $StatRowHP/LabelHP
@onready var hp_bar: ProgressBar = $StatRowHP/HPBar
@onready var label_ap: Label = $StatRowAP/LabelAP


func update_stats(stats: CharacterStats) -> void:
	if stats == null:
		return

	update_hp(
		stats.current_hp,
		stats.max_hp
	)

	update_ap(
		stats.current_ap,
		stats.max_ap
	)


func update_hp(
	current_hp: int,
	max_hp: int
) -> void:

	_set_label_text(
		label_hp,
		HP_FORMAT % [current_hp, max_hp]
	)

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp


func update_ap(
	current_ap: int,
	max_ap: int
) -> void:

	_set_label_text(
		label_ap,
		AP_FORMAT % [current_ap, max_ap]
	)


func _set_label_text(
	label: Label,
	value: String
) -> void:

	if label == null:
		return

	label.text = value
