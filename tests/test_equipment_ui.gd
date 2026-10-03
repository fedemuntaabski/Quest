extends SceneTree

## Session impl-6, fase 2B: equipment UI over a live Main2d + HUD.
##   - the sheet's "Equipo" section lists the stash; clicking a stash cell equips,
##     clicking an equipped slot unequips; stats follow
##   - a full stash blocks unequipping with a message; a wrong hero is refused
##   - "Usar" and the portrait shortcut use a consumable; tactical pause blocks it
##   - the HUD counter follows the stash
##   godot --headless --path . --script res://tests/test_equipment_ui.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []
var ps: Node
var inv: Node


func _initialize() -> void:
	ps = root.get_node("PlayerStats")
	inv = root.get_node("PartyInventory")
	await process_frame
	await _test()
	inv.reset()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_equipment_ui: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _item(id: String) -> ItemData:
	return load("res://resources/items/%s.tres" % id) as ItemData


func _test() -> void:
	inv.reset()
	ps.reset_run_upgrades()
	ps.clear_party()
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame

	var warrior: Player = main2d.heroes[0]
	var portrait: HeroPortrait = hud.portraits.get_child(0)
	var popup: CharacterPopup = hud.character_popup
	var section: EquipmentSection = popup._equipment
	hud.open_hero_sheet(portrait)
	_expect(popup.visible and section.hero_id == warrior.stats.hero_id, "sheet opens bound to the hero")
	_expect(section._slots_row.get_child_count() == 5, "5 slots: weapon, armor, relic, 2 consumables (%d)" % section._slots_row.get_child_count())
	_expect(hud._stash_label.text == "Mochila 0/20", "counter starts empty: '%s'" % hud._stash_label.text)

	# Stash cell -> equip.
	var sword := _item("sword_iron")
	inv.add_item(sword)
	_expect(section._stash_grid.get_child_count() == 1 and hud._stash_label.text == "Mochila 1/20", "stash cell and counter follow add_item")
	var damage_before := warrior.stats.attack_damage
	(section._stash_grid.get_child(0) as Button).pressed.emit()
	_expect(inv.get_equipped(warrior.stats.hero_id, ItemData.Slot.WEAPON).size() == 1, "clicking a stash cell equips it")
	_expect(warrior.stats.attack_damage == damage_before + int(sword.modifiers.get("attack_damage", 0)), "equipping changes the damage by the item's modifier")
	_expect(section._stash_grid.get_child_count() == 0 and section._bonus_label.text.begins_with("Equipo suma"), "stash empties, bonus line shows")

	# Equipped slot -> unequip; full stash blocks it.
	var weapon_cell := (section._slots_row.get_child(0) as VBoxContainer).get_child(0) as Button
	_expect(weapon_cell.tooltip_text.contains("desequipar"), "equipped slot tooltip: '%s'" % weapon_cell.tooltip_text)
	while inv.stash_size() < 20:
		inv.add_item(_item("sword_gold"))  # not stackable: one stack each
	_expect(not inv.can_add(sword), "stash is full")
	_expect(hud._stash_label.text == "Mochila 20/20", "counter shows 20/20: '%s'" % hud._stash_label.text)
	(((section._slots_row.get_child(0) as VBoxContainer).get_child(0)) as Button).pressed.emit()
	_expect(section._message.text == "Mochila llena" and inv.get_equipped(warrior.stats.hero_id, ItemData.Slot.WEAPON).size() == 1, "unequip into a full stash is blocked with a message")
	inv.reset()
	await process_frame

	# Wrong hero: the robe is for mage/rogue only.
	var robe := _item("armor_robe")
	inv.add_item(robe)
	(section._stash_grid.get_child(0) as Button).pressed.emit()
	_expect(section._message.text != "" and inv.get_equipped(warrior.stats.hero_id, ItemData.Slot.ARMOR).is_empty(), "a restricted item is refused with a reason: '%s'" % section._message.text)

	# Consumables: "Usar" button + portrait shortcut, blocked in tactical pause.
	var potion := _item("potion_health")
	inv.add_item(potion)
	inv.add_item(potion)
	inv.equip(warrior.stats.hero_id, potion)
	inv.equip(warrior.stats.hero_id, potion)
	var shortcut: Button = portrait._consumable_buttons[0]
	_expect(shortcut.visible, "portrait shows a shortcut for the equipped consumable")
	warrior.stats.current_hp = 5
	Engine.time_scale = 0.0
	var use_button := ((section._slots_row.get_child(3) as VBoxContainer).get_child(1)) as Button
	use_button.pressed.emit()
	_expect(section._message.text.begins_with("No se puede usar en pausa") and warrior.stats.current_hp == 5, "'Usar' is blocked in tactical pause: '%s'" % section._message.text)
	Engine.time_scale = 1.0
	shortcut.pressed.emit()
	_expect(warrior.stats.current_hp > 5, "the portrait shortcut uses the potion (hp %d)" % warrior.stats.current_hp)
	_expect(inv.get_equipped(warrior.stats.hero_id, ItemData.Slot.CONSUMABLE).size() == 1, "one potion left in the slots")

	hud.queue_free()
	main2d.queue_free()
	Engine.time_scale = 1.0
	await process_frame
	await process_frame
