extends SceneTree

## Session 13: 2-hero selection. GameSession only accepts 2 distinct known heroes,
## HeroSelectMenu enforces the same rules (add/remove, no 3rd, Start only with 2),
## Main2d spawns the chosen pair in pick order (per-hero HP, HUD portraits and
## sheet for any pair) and falls back to the old default party with no pick.
##   godot --headless --path . --script res://tests/test_hero_select.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"
const MENU_PATH := "res://scenes/menus/HeroSelectMenu.tscn"

var failures: Array[String] = []
var session: Node
var ps: Node


func _initialize() -> void:
	session = root.get_node("GameSession")
	ps = root.get_node("PlayerStats")
	root.get_node("ResourceManager").reset_resources(15, 15, 10, 20)
	ps.reset_run_upgrades()

	_check_session()
	await _check_menu()
	await _check_spawn(["rogue", "tank"])
	await _check_spawn(["mage", "warrior"])
	await _check_default()

	session.clear()
	ps.reset_run_upgrades()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_hero_select: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for id in list:
		out.append(id)
	return out


# ---------------- GameSession ----------------

func _check_session() -> void:
	session.clear()
	_expect(not session.has_selection() and session.get_party_ids().is_empty(), "fresh session should have no pick")
	_expect(not session.set_selection(_ids(["rogue"])), "1 hero accepted")
	_expect(not session.set_selection(_ids(["rogue", "tank", "mage"])), "3 heroes accepted")
	_expect(not session.set_selection(_ids(["rogue", "rogue"])), "duplicate accepted")
	_expect(not session.set_selection(_ids(["rogue", "ghost"])), "unknown id accepted")
	_expect(not session.has_selection(), "a rejected pick must not be stored")
	_expect(session.set_selection(_ids(["tank", "rogue"])), "valid pair rejected")
	_expect(session.get_party_ids() == _ids(["tank", "rogue"]), "pick order lost: %s" % [session.get_party_ids()])
	var copy: Array[String] = session.get_party_ids()
	copy.clear()
	_expect(session.has_selection(), "get_party_ids must return a copy")
	session.clear()
	_expect(not session.has_selection(), "clear() left a pick")


# ---------------- HeroSelectMenu ----------------

func _check_menu() -> void:
	var menu := (load(MENU_PATH) as PackedScene).instantiate() as HeroSelectMenu
	root.add_child(menu)
	await process_frame
	var confirmed: Array = []
	menu.heroes_confirmed.connect(func(ids: Array[String]) -> void: confirmed.append(ids))
	var backs := [0]
	menu.back_pressed.connect(func() -> void: backs[0] += 1)

	_expect(CharacterDatabase.get_all().size() == 4, "expected 4 heroes")
	_expect(menu._cards.size() == 4, "expected 4 cards, got %d" % menu._cards.size())
	_expect(menu.start_button.disabled and not menu.can_start(), "Start should begin disabled")

	_expect(menu.toggle_hero("rogue") and menu.selected == _ids(["rogue"]), "first pick")
	_expect(menu.start_button.disabled, "Start enabled with 1 hero")
	_expect(menu.toggle_hero("tank") and menu.selected == _ids(["rogue", "tank"]), "second pick")
	_expect(menu.can_start() and not menu.start_button.disabled, "Start should enable with 2 heroes")
	_expect(not menu.toggle_hero("mage") and menu.selected == _ids(["rogue", "tank"]), "a 3rd pick must be refused")
	_expect(menu.toggle_hero("rogue") and menu.selected == _ids(["tank"]) and menu.start_button.disabled, "clicking a chosen hero should remove it")
	menu._slots[0].pressed.emit()  # slot 1 now holds "tank": click removes it
	_expect(menu.selected.is_empty(), "clicking a slot should remove its hero")
	menu.toggle_hero("mage")
	menu.toggle_hero("warrior")
	_expect(menu._slots[0].text.contains("Mago") and menu._slots[1].text.contains("Guerrero"), "slots should show the picks in order")

	# Real card press (the click path), preview follows.
	menu.toggle_hero("mage")
	menu._cards["tank"].pressed.emit()
	_expect(menu.selected == _ids(["warrior", "tank"]) and menu._preview_id == "tank", "card press: %s / preview %s" % [menu.selected, menu._preview_id])
	var frames: SpriteFrames = CharacterDatabase.get_by_id("tank").sprite_frames
	_expect(menu._preview_sprite.sprite_frames == frames and menu._preview_sprite.animation == &"idle", "preview should play the hero's idle")
	_expect(menu._preview_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "preview must use Nearest")
	var tank_hp: int = CharacterDatabase.get_by_id("tank").base_hp
	_expect(menu._preview_info.text.contains("Vida: %d" % tank_hp), "preview stats: %s" % menu._preview_info.text)

	menu.start_button.pressed.emit()
	_expect(confirmed.size() == 1 and confirmed[0] == _ids(["warrior", "tank"]), "confirm payload %s" % [confirmed])
	menu.toggle_hero("tank")
	menu.start_button.pressed.emit()
	_expect(confirmed.size() == 1, "Start with 1 hero must not confirm")
	menu.back_button.pressed.emit()
	_expect(backs[0] == 1, "Volver should emit back_pressed")

	# Keyboard: cards are focusable buttons (arrows/Enter are Godot's own focus + ui_accept).
	_expect(menu._cards["mage"].focus_mode == Control.FOCUS_ALL, "cards should take focus")
	menu.queue_free()
	await process_frame


# ---------------- Spawn / HUD ----------------

func _boot() -> Array:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	return [main2d, hud]


func _free_world(world: Array) -> void:
	paused = false
	for node: Node in world:
		node.queue_free()
	await process_frame
	await process_frame


func _check_spawn(pick: Array) -> void:
	var ids := _ids(pick)
	ps.reset_run_upgrades()
	_expect(session.set_selection(ids), "pick %s rejected" % [ids])
	var world: Array = await _boot()
	var main2d: Node = world[0]
	var hud: HUDController = world[1]
	var label := "pick %s" % [ids]

	var spawned: Array[String] = []
	for hero: Player in main2d.heroes:
		spawned.append(hero.stats.hero_id)
	_expect(spawned == ids, "%s: spawned %s" % [label, spawned])
	_expect(ps.get_hero_ids() == ids and ps.active_hero_id == ids[0], "%s: PlayerStats party %s active '%s'" % [label, ps.get_hero_ids(), ps.active_hero_id])
	_expect(main2d.player == main2d.heroes[0], "%s: player should be the first pick" % label)

	_expect(hud.portraits.get_child_count() == 2, "%s: %d portraits" % [label, hud.portraits.get_child_count()])
	for i in ids.size():
		var hero: Player = main2d.heroes[i]
		var data := CharacterDatabase.get_by_id(ids[i])
		_expect(hero.stats.max_hp == data.base_hp and hero.stats.current_hp == data.base_hp, "%s: '%s' hp %d/%d, expected %d" % [label, ids[i], hero.stats.current_hp, hero.stats.max_hp, data.base_hp])
		_expect(hero.stats.attack_damage == data.attack_damage, "%s: '%s' damage %d" % [label, ids[i], hero.stats.attack_damage])
		var portrait: HeroPortrait = hud.portraits.get_child(i)
		_expect(portrait.stats == hero.stats, "%s: portrait %d bound to the wrong hero" % [label, i])
		hud.open_hero_sheet(portrait)
		_expect(hud.character_popup.visible and hud.character_popup.stats == hero.stats and hud.character_popup._title.text == data.display_name, "%s: sheet of '%s'" % [label, ids[i]])
		hud.character_popup.close()
	# The HUD reads HP from the hero's own stats.
	main2d.heroes[1].stats.take_damage(3)
	_expect(main2d.heroes[0].stats.current_hp == main2d.heroes[0].stats.max_hp, "%s: damage leaked between heroes" % label)

	await _free_world(world)


func _check_default() -> void:
	session.clear()
	ps.reset_run_upgrades()
	var world: Array = await _boot()
	var spawned: Array[String] = []
	for hero: Player in world[0].heroes:
		spawned.append(hero.stats.hero_id)
	_expect(spawned == _ids(["warrior", "mage"]), "no pick: default party %s" % [spawned])
	_expect(world[1].portraits.get_child_count() == 2, "no pick: HUD portraits")
	await _free_world(world)
