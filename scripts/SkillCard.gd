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
		var stat_key := str(data.get("stat", "strength"))
		stat_icon.text = "Atributo: %s" % StatTypes.get_label(stat_key)

	if damage_label:
		damage_label.text = "Dano: %d" % int(data.get("base_damage", 0))
