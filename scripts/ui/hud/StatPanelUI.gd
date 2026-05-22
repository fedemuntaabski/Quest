extends Control
class_name StatPanelUI

@onready var label_hp: Label = $StatRowHP/LabelHP
@onready var label_strength: Label = $StatRowStrength/LabelStrength
@onready var label_magic: Label = $StatRowMagic/LabelMagic
@onready var label_dexterity: Label = $StatRowDexterity/LabelDexterity

func update_stats(stats: CharacterStats) -> void:
	if stats == null:
		return

	var total_strength: int = stats.get_total_strength()
	var total_magic: int = stats.get_total_magic()
	var total_dexterity: int = stats.get_total_dexterity()

	label_hp.text = "HP %d/%d" % [stats.current_hp, stats.max_hp]
	label_strength.text = "Fuerza %d" % total_strength
	label_magic.text = "Magia %d" % total_magic
	label_dexterity.text = "Agilidad %d" % total_dexterity

func update_hp(current_hp: int, max_hp: int) -> void:
	label_hp.text = "HP %d/%d" % [current_hp, max_hp]
