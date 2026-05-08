extends Control
class_name SkillCard

@onready var card_name: Label = $Panel/VBoxContainer/CardName
@onready var card_description: Label = $Panel/VBoxContainer/CardDescription
@onready var stat_icon: Label = $Panel/VBoxContainer/StatIcon
@onready var damage_label: Label = $Panel/VBoxContainer/DamageLabel

func set_data(data: Dictionary) -> void:
	if card_name:
		card_name.text = data.get("name", "Skill")

	if card_description:
		card_description.text = data.get("description", "")

	if stat_icon:
		stat_icon.text = "Stat: %s" % data.get("stat", "strength")

	if damage_label:
		damage_label.text = "Damage: %d" % int(data.get("base_damage", 0))
