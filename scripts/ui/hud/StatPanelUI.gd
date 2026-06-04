extends Control
class_name StatPanelUI

const HP_FORMAT := "HP %d/%d"
const STRENGTH_FORMAT := "Fuerza %d"
const MAGIC_FORMAT := "Magia %d"
const DEXTERITY_FORMAT := "Agilidad %d"

@onready var label_hp: Label = $StatRowHP/LabelHP
@onready var label_strength: Label = $StatRowStrength/LabelStrength
@onready var label_magic: Label = $StatRowMagic/LabelMagic
@onready var label_dexterity: Label = $StatRowDexterity/LabelDexterity


func update_stats(stats: CharacterStats) -> void:
	if stats == null:
		return

	update_hp(
		stats.current_hp,
		stats.max_hp
	)

	_set_label_text(
		label_strength,
		STRENGTH_FORMAT % stats.get_total_strength()
	)

	_set_label_text(
		label_magic,
		MAGIC_FORMAT % stats.get_total_magic()
	)

	_set_label_text(
		label_dexterity,
		DEXTERITY_FORMAT % stats.get_total_dexterity()
	)


func update_hp(
	current_hp: int,
	max_hp: int
) -> void:

	_set_label_text(
		label_hp,
		HP_FORMAT % [current_hp, max_hp]
	)


func _set_label_text(
	label: Label,
	value: String
) -> void:

	if label == null:
		return

	label.text = value