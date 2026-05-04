extends Control
class_name UpgradePanelUI

@onready var vbox: VBoxContainer = $ScrollContainer/VBoxContainer

func refresh(upgrades: Array) -> void:
	for child in vbox.get_children():
		child.queue_free()

	if upgrades.is_empty():
		var lbl = Label.new()
		lbl.text = "No cards equipped."
		vbox.add_child(lbl)
		return

	var count := 0
	for upg in upgrades:
		if count >= 3:
			break

		var card = Label.new()
		card.text = "%s (%s +%d)" % [
			upg.get("card_name", "???"),
			upg.get("stat_affected", ""),
			upg.get("value_change", 0)
		]

		vbox.add_child(card)
		count += 1