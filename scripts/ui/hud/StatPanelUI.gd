extends HBoxContainer
class_name StatPanelUI

## Top-left resource bar: per resource an icon, the amount and the per-turn
## gain (ResourceManager.get_turn_yield).

@onready var amount_labels := {
	"iron": $ChipIron/LabelIron as Label,
	"food": $ChipFood/LabelFood as Label,
	"lore": $ChipLore/LabelLore as Label,
	"embers": $ChipEmbers/LabelEmbers as Label,
}

@onready var gain_labels := {
	"iron": $ChipIron/GainIron as Label,
	"food": $ChipFood/GainFood as Label,
	"lore": $ChipLore/GainLore as Label,
	"embers": $ChipEmbers/GainEmbers as Label,
}


func update_resource(key: String, amount: int) -> void:
	var label: Label = amount_labels.get(key)
	if label:
		label.text = str(amount)


## Hidden when the resource has no per-turn income (embers today).
func update_gain(key: String, amount: int) -> void:
	var label: Label = gain_labels.get(key)
	if label == null:
		return
	label.text = "+%d" % amount
	label.visible = amount > 0
