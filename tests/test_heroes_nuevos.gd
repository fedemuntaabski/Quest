extends SceneTree

## personajes-46: two new heroes, Ballestero (ranger) and Clériga (cleric). Complete data
## (stats, art with attack/fall frames, passive + active AbilityData with text and icon, 4 perks),
## effects no other hero uses, listed in HeroSelectMenu and as Prisoner candidates, and each
## ability doing its own thing on a live Main2d:
##  - Clériga: passive heals the living allies in her room over time; Q heals them at once;
##  - Ballestero: passive pays Hierro for each enemy he kills; Q slows the enemies in his reach.
##   godot --headless --path . --script res://tests/test_heroes_nuevos.gd

const NEW: Array[String] = ["ranger", "cleric"]
const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const MENU_PATH := "res://scenes/menus/HeroSelectMenu.tscn"
const GOBLIN_PATH := "res://resources/enemies/goblin.tres"

var failures: Array[String] = []


func _initialize() -> void:
	var ok := true
	for id in NEW:
		_expect(CharacterDatabase.has_id(id), "%s: not in CharacterDatabase" % id)
		ok = ok and CharacterDatabase.has_id(id)
	if ok:
		_check_data()
		await _check_menu()
		_check_recruit()
		await _check_cleric()
		await _check_ranger()
		await _check_sheet()
		_check_icons()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_heroes_nuevos: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_data() -> void:
	for id in NEW:
		var data := CharacterDatabase.get_by_id(id)
		_expect(data.display_name != "" and data.role != "" and data.description != "" and data.passive_ability_desc != "", "%s: texts missing" % id)
		_expect(data.base_hp > 0 and data.attack_damage > 0 and data.attack_interval > 0.0 and data.attack_range > 0.0, "%s: stats missing" % id)
		_expect(data.sprite_frames != null, "%s: no sprite_frames" % id)
		if data.sprite_frames:
			for anim in ["idle", "run", "hit", "attack", "fall"]:
				_expect(data.sprite_frames.has_animation(anim), "%s: no '%s' animation" % [id, anim])
		_expect(data.passive != null and not data.passive.is_active(), "%s: no passive" % id)
		_expect(data.active != null and data.active.is_active(), "%s: no active" % id)
		for ability: AbilityData in [data.passive, data.active]:
			if ability == null:
				continue
			_expect(ability.display_name != "" and ability.icon != null, "%s: %s without name or icon" % [id, ability.id])
			_expect(ability.description != "" and not ability.format_description().contains("{"), "%s: %s description not filled" % [id, ability.id])
		_expect(data.perks.size() == 4, "%s: %d perks, want 4" % [id, data.perks.size()])
		if data.passive == null or data.active == null:
			continue
		for other: CharacterData in CharacterDatabase.get_all():
			if other.character_id == id:
				continue
			for ability: AbilityData in [other.passive, other.active]:
				_expect(ability.effect != data.passive.effect and ability.effect != data.active.effect,
					"%s repeats %s's effect %s" % [id, other.character_id, AbilityData.Effect.keys()[ability.effect]])


func _check_menu() -> void:
	var menu := (load(MENU_PATH) as PackedScene).instantiate() as HeroSelectMenu
	root.add_child(menu)
	await process_frame
	for id in NEW:
		_expect(menu._cards.has(id), "HeroSelectMenu: no card for %s" % id)
	menu.queue_free()
	await process_frame


func _check_recruit() -> void:
	var session := root.get_node("GameSession")
	session.clear()
	var candidates: Array[String] = session.get_recruit_candidates(["warrior", "mage"] as Array[String])
	for id in NEW:
		_expect(candidates.has(id), "PrisonerSpawner: %s is no recruit candidate (%s)" % [id, candidates])


func _boot(pick: Array[String]) -> Node:
	var session := root.get_node("GameSession")
	session.clear()
	_expect(session.set_selection(pick), "pick %s refused" % [pick])
	root.get_node("PlayerStats").reset_run_upgrades()
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	main2d.camera.config = main2d.camera.config.duplicate()
	main2d.camera.config.edge_scroll_enabled = false
	return main2d


func _free(main2d: Node) -> void:
	Engine.time_scale = 1.0
	main2d.queue_free()
	root.get_node("GameSession").clear()
	await process_frame
	await process_frame


func _wait_game(sec: float) -> void:
	Engine.time_scale = 4.0
	await create_timer(sec).timeout
	Engine.time_scale = 1.0


func _hero(main2d: Node, id: String) -> Player:
	for hero: Player in main2d.heroes:
		if hero.stats.hero_id == id:
			return hero
	return null


func _check_cleric() -> void:
	var main2d: Node = await _boot(["cleric", "ranger"] as Array[String])
	var cleric := _hero(main2d, "cleric")
	var ally := _hero(main2d, "ranger")
	_expect(cleric.current_zone_id == ally.current_zone_id, "cleric and ranger start apart")
	ally.stats.take_damage(10)
	var hp := ally.stats.current_hp
	await _wait_game(cleric.abilities.passive.cooldown * 2.5)
	_expect(ally.stats.current_hp > hp, "cleric passive: an ally in her room did not heal over time (%d -> %d)" % [hp, ally.stats.current_hp])
	ally.stats.take_damage(10)
	hp = ally.stats.current_hp
	_expect(cleric.abilities.try_activate(), "cleric: Q refused (%s)" % cleric.abilities.get_block_reason())
	_expect(ally.stats.current_hp >= mini(hp + roundi(cleric.abilities.active_value()), ally.stats.max_hp), "cleric Q: ally %d -> %d HP" % [hp, ally.stats.current_hp])
	await _free(main2d)


## The hero sheet (owner's "Libro abierto" mockup) fits the screen at the biggest text and Esc closes it.
func _check_sheet() -> void:
	var settings := root.get_node("SettingsManager")
	var old_scale: float = settings.text_scale
	settings.text_scale = settings.TEXT_SCALE_MAX
	var main2d: Node = await _boot(["cleric", "ranger"] as Array[String])
	var hud := (load("res://scenes/hud/HUD.tscn") as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	hud.open_hero_sheet(hud.portraits.get_child(0))
	for i in 4:
		await process_frame
	var popup := hud.character_popup
	var frame := popup.find_child("Frame", true, false) as Control
	_expect(frame != null and root.get_visible_rect().encloses(frame.get_global_rect()), "sheet at x%.1f text off screen: %s in %s" % [settings.TEXT_SCALE_MAX, frame.get_global_rect() if frame else null, root.get_visible_rect()])
	_expect(popup._title.text == "Clériga" and popup._level_button.text.contains("Comida"), "sheet: title '%s', level button '%s'" % [popup._title.text, popup._level_button.text])
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	popup._input(esc)
	_expect(not popup.visible, "Esc does not close the sheet")
	settings.text_scale = old_scale
	hud.queue_free()
	await _free(main2d)


## personajes-46 (owner's request): every perk, Obra and resource has its own LibreSprite icon
## (assets/art/own, from tools/libresprite_icons.js), and a built Obra shows its menu icon on the map.
func _check_icons() -> void:
	for data: CharacterData in CharacterDatabase.get_all():
		for perk: HeroPerk in data.perks:
			_expect(perk.icon != null and perk.icon.resource_path.begins_with("res://assets/art/own/perks/"), "%s: perk %s without its own icon" % [data.character_id, perk.id])
	for type: int in Building.CATALOG:
		var path := str(Building.CATALOG[type]["icon"])
		_expect(path.begins_with("res://assets/art/own/buildings/") and ResourceLoader.exists(path), "%s: Obra icon %s" % [Building.BuildingType.keys()[type], path])
		var building := (load("res://scenes/world/Building.tscn") as PackedScene).instantiate() as Building
		root.add_child(building)
		building.configure("room_0", type)
		_expect(building.art != null and building.art.texture and building.art.texture.resource_path == path and building.art.visible,
			"%s: the built Obra does not show its menu icon" % Building.BuildingType.keys()[type])
		building.free()
	for key in ["hp", "iron", "food", "lore", "embers", "lock"]:
		_expect(StatIcon.art_for(key) != null, "resource icon %s missing" % key)


func _check_ranger() -> void:
	var main2d: Node = await _boot(["ranger", "cleric"] as Array[String])
	var ranger := _hero(main2d, "ranger")
	var resources := root.get_node("ResourceManager")
	var enemy := EnemyManager.ENEMY_SCENE.instantiate() as Enemy
	main2d.enemy_manager._enemies_root.add_child(enemy)
	enemy.setup(ranger.global_position + Vector2(60, 0))
	enemy.configure(Enemy.Variant.SWARM, ranger.current_zone_id, 1.0, 1.0, load(GOBLIN_PATH))
	enemy.ai_timer.stop()
	await process_frame
	await physics_frame
	await physics_frame
	_expect(ranger.abilities.try_activate(), "ranger: Q refused (%s)" % ranger.abilities.get_block_reason())
	_expect(Enemy.game_msec() < enemy._slowed_until_msec, "ranger Q: the enemy in his reach is not slowed")
	var iron: int = resources.get_resource("iron")
	enemy.current_hp = 1
	enemy.hurtbox.receive_hit(5)
	ranger.hitbox.hit_landed.emit(enemy.hurtbox, 5)
	_expect(resources.get_resource("iron") == iron + roundi(ranger.abilities.passive_value()), "ranger passive: Hierro %d -> %d after a kill" % [iron, resources.get_resource("iron")])
	await _free(main2d)
