extends Control
class_name StatPanelUI

@onready var label_hp: Label = $HBoxContainer_HP/LabelHP
@onready var label_strength: Label = $HBoxContainer_Strength/LabelStrength
@onready var label_magic: Label = $HBoxContainer_Magic/LabelMagic
@onready var label_dexterity: Label = $HBoxContainer_Dexterity/LabelDexterity

func update_stats(stats: CharacterStats, base: Dictionary) -> void:
	if stats == null:
		return

	var b_hp = base.get("hp", 10)
	var b_str = base.get("strength", 0)
	var b_mag = base.get("magic", 0)
	var b_dex = base.get("dexterity", 0)

	var str_total = stats.get_total_strength()
	var mag_total = stats.get_total_magic()
	var dex_total = stats.get_total_dexterity()

	label_strength.text = "STR: %d + %d" % [b_str, str_total - b_str]
	label_magic.text = "MAG: %d + %d" % [b_mag, mag_total - b_mag]
	label_dexterity.text = "DEX: %d + %d" % [b_dex, dex_total - b_dex]