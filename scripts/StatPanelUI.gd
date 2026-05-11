extends Control
class_name StatPanelUI

@onready var label_hp: Label = $HBoxContainer/VBoxContainer/HBoxContainer_HP/LabelHP
@onready var label_strength: Label = $HBoxContainer/VBoxContainer/HBoxContainer_Strength/LabelStrength
@onready var label_magic: Label = $HBoxContainer/VBoxContainer/HBoxContainer_Magic/LabelMagic
@onready var label_dexterity: Label = $HBoxContainer/VBoxContainer/HBoxContainer_Dexterity/LabelDexterity

func update_stats(stats: CharacterStats, base: Dictionary) -> void:
	if stats == null:
		return

	var _b_hp: int = base.get("hp", 10)
	var b_str: int = base.get("strength", 0)
	var b_mag: int = base.get("magic", 0)
	var b_dex: int = base.get("dexterity", 0)

	label_hp.text = "HP: %d/%d" % [stats.current_hp, stats.max_hp]
	label_strength.text = "%s: %d + %d" % [StatTypes.get_label(StatTypes.STRENGTH), b_str, stats.get_total_strength() - b_str]
	label_magic.text = "%s: %d + %d" % [StatTypes.get_label(StatTypes.MAGIC), b_mag, stats.get_total_magic() - b_mag]
	label_dexterity.text = "%s: %d + %d" % [StatTypes.get_label(StatTypes.DEXTERITY), b_dex, stats.get_total_dexterity() - b_dex]

func update_hp(current_hp: int, max_hp: int) -> void:
	label_hp.text = "HP: %d/%d" % [current_hp, max_hp]
