extends SceneTree

## session/estabilizar-14: regressions of the cross-system bugs of the audit, on
## the real Main orchestrator (Main is PROCESS_MODE_ALWAYS and everything under
## it inherits that, which a bare Main2d under root would hide):
##   1. Esc freezes the world and Esc closes the menu again; run time stops.
##   2. Victory and defeat are terminal: neither replaces the other.
##   3. Level-up / equipment never revive a downed hero.
##   4. A walking hero changes zone on the way (traps, chests, Nexo drop); a
##      fallen one stops where it fell.
##   5. Door invasions use the PlayerScaling count.
##   + minors: trap/boss charge go through the passives, a revived hero is back
##     in its selection and groups, boss bar on clients, hints under the sheet.
##   godot --headless --path . --script res://tests/test_estabilizar.gd

const MAIN_PATH := "res://scenes/Main.tscn"
const SLOT := 92
const HUGE_HP := 100000
const ARMOR: ItemData = preload("res://resources/items/armor_iron.tres")

var failures: Array[String] = []
var _main: Main
var ps: Node
var resources: ResourceManager
var inventory: PartyInventory
var selection: Node


func _initialize() -> void:
	ps = root.get_node("PlayerStats")
	resources = root.get_node("ResourceManager") as ResourceManager
	inventory = root.get_node("PartyInventory") as PartyInventory
	selection = root.get_node("SelectionManager")
	await process_frame
	_main = (load(MAIN_PATH) as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _frames(20)
	root.get_node("SaveManager").load_game(SLOT)
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()

	await _check_esc_freezes_the_world()
	await _new_run()
	await _check_victory_is_terminal()
	await _new_run()
	await _check_defeat_is_terminal()
	await _new_run()
	await _check_downed_stays_down()
	await _new_run()
	await _check_zone_on_the_way()
	await _new_run()
	await _check_carrier_falls_on_the_way()
	await _new_run()
	await _check_door_scaling()
	await _new_run()
	await _check_damage_paths()
	await _new_run()
	_check_revived_selection()
	_check_boss_puppet()
	_check_hint_under_sheet()

	paused = false
	Engine.time_scale = 1.0
	await _main.return_to_main_menu()
	await _frames(10)
	_main.queue_free()
	await _frames(5)
	root.get_node("SaveManager").delete_save(SLOT)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_estabilizar: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout  # also while paused, real time


func _new_run() -> void:
	paused = false
	await _main.reload_gameplay()
	await _frames(5)


func _main2d() -> Node:
	return _main.world_container.get_child(_main.world_container.get_child_count() - 1)


## An enemy on top of `hero`, tick-attacking it.
func _enemy_on(hero: Player) -> Enemy:
	var enemy: Enemy = _main2d().enemy_manager._spawn_enemy(hero.current_zone_id, hero.global_position)
	enemy.max_hp = HUGE_HP
	enemy.current_hp = HUGE_HP
	return enemy


func _key(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


# ---------------- 1. Esc ----------------

func _check_esc_freezes_the_world() -> void:
	var main2d := _main2d()
	var hero: Player = main2d.heroes[0]
	hero.stats.max_hp = HUGE_HP
	hero.stats.current_hp = HUGE_HP
	var enemy := _enemy_on(hero)
	await _seconds(0.3)

	root.push_input(_key(&"ui_cancel"))
	await _frames(3)
	_expect(paused and main2d.pause_menu.is_open, "Esc should open the menu and pause the tree")
	_expect(main2d.pause_menu.can_process() and main2d.death_overlay.can_process() and main2d.victory_overlay.can_process(), "menu and end screens must work while paused")
	_expect(not hero.can_process() and not enemy.can_process() and not main2d.enemy_manager.can_process(), "the world must not process while paused")

	var hp: int = hero.stats.current_hp
	var enemy_hp := enemy.current_hp
	var clock := Enemy.game_time_msec
	var enemies: int = main2d.enemy_manager.alive_count()
	var session := root.get_node("GameSession")
	var elapsed := float(session.run_stats["elapsed_sec"])
	await _seconds(1.5)
	_expect(hero.stats.current_hp == hp, "hero HP changed with the menu open (%d -> %d)" % [hp, hero.stats.current_hp])
	_expect(enemy.current_hp == enemy_hp, "enemy HP changed with the menu open (%d -> %d)" % [enemy_hp, enemy.current_hp])
	_expect(Enemy.game_time_msec == clock, "game clock ran with the menu open")
	_expect(main2d.enemy_manager.alive_count() == enemies, "enemies spawned with the menu open")

	# Esc reaches an open sub-panel first: it closes that, not the whole menu.
	main2d.pause_menu._set_panel(2)
	root.push_input(_key(&"ui_cancel"))
	await _seconds(0.3)
	_expect(main2d.pause_menu.is_open and not main2d.pause_menu.bestiary_panel.visible, "Esc on a sub-panel should close only the panel")

	# Esc must still work on a paused tree: Main2d itself doesn't process then.
	root.push_input(_key(&"ui_cancel"))
	await _seconds(0.4)
	_expect(not main2d.pause_menu.is_open and not paused, "a second Esc should close the menu and resume")
	_expect(float(session.run_stats["elapsed_sec"]) - elapsed < 0.9, "the Esc pause must not count as run time (+%.2f s)" % (float(session.run_stats["elapsed_sec"]) - elapsed))
	await _seconds(0.3)
	_expect(Enemy.game_time_msec > clock, "game clock should run again after resuming")


# ---------------- 2. terminal states ----------------

func _check_victory_is_terminal() -> void:
	var main2d := _main2d()
	var gsm: GameStateManager = main2d.game_state_manager
	for hero: Player in main2d.heroes:
		hero.stats.current_hp = 1
		_enemy_on(hero)
	await _frames(2)
	main2d.extraction_manager.declare_victory()
	await _seconds(2.0)
	_expect(gsm.current_state == GameStateManager.State.VICTORY, "enemies in contact turned the victory into state %s" % gsm.current_state)
	_expect(not main2d.death_overlay.visible and main2d.victory_overlay.visible, "only the victory overlay should be up")
	var next_button := main2d.victory_overlay.find_child("NextFloorButton", true, false) as Button
	_expect(next_button != null and next_button.can_process(), "victory buttons must work on the paused tree")

	# Even a defeat that does get through (Nexo destroyed) can't replace it.
	main2d._on_player_died()
	_expect(gsm.current_state == GameStateManager.State.VICTORY and not main2d._is_dead and not main2d.death_overlay.visible, "a late defeat must not replace the victory")


func _check_defeat_is_terminal() -> void:
	var main2d := _main2d()
	var gsm: GameStateManager = main2d.game_state_manager
	var session := root.get_node("GameSession")
	var cleared := int(session.run_stats["floors_cleared"])
	main2d._on_player_died()
	main2d.extraction_manager.declare_victory()
	_expect(gsm.current_state == GameStateManager.State.DEAD, "a late victory must not replace the defeat")
	_expect(int(session.run_stats["floors_cleared"]) == cleared, "a late victory must not complete the floor")
	_expect(not main2d.victory_overlay.visible, "no victory overlay after a defeat")


# ---------------- 3. downed ----------------

func _check_downed_stays_down() -> void:
	var main2d := _main2d()
	var hero: Player = main2d.heroes[1]
	var id: String = hero.stats.hero_id
	resources.add_resource("food", 500)
	hero.stats.take_damage(HUGE_HP)
	_expect(hero.is_downed(), "setup: hero downed")

	_expect(ps.level_up_hero(id), "a downed hero can still be leveled")
	_expect(hero.is_downed() and hero.stats.current_hp == 0, "level-up revived a downed hero (%d HP)" % hero.stats.current_hp)
	inventory.add_item(ARMOR)
	_expect(inventory.equip(id, ARMOR), "a downed hero can still be equipped")
	_expect(hero.is_downed() and hero.stats.current_hp == 0, "equipment revived a downed hero (%d HP)" % hero.stats.current_hp)
	_expect(inventory.unequip(id, ARMOR.slot), "a downed hero can still be unequipped")
	_expect(hero.is_downed() and hero.stats.current_hp == 0, "unequip changed a downed hero's HP")

	_expect(ps.revive_hero(id), "the paid revive still works")
	var pct: float = ps._config_for(id).revive_hp_pct
	_expect(hero.stats.current_hp == maxi(1, roundi(hero.stats.max_hp * pct)), "revive HP from the leveled max (%d/%d)" % [hero.stats.current_hp, hero.stats.max_hp])


# ---------------- 4. zone on the way ----------------

## Opens every door; returns the zones from the start to a room two rooms away.
func _long_path(main2d: Node) -> Array[String]:
	var rm: RoomManager = main2d.room_manager
	var opened := true
	while opened:
		opened = false
		for door in rm.get_all_doors():
			if not door.is_open and rm.is_zone_revealed(door.from_zone_id):
				main2d.door_turn_system.open_room(door.target_room_id)
				door.disable_door()
				opened = true
	var best: Array[String] = []
	var start := rm.get_start_zone_id()
	for zone_id: String in rm.zones:
		var path := rm.find_zone_path(start, zone_id)
		if rm.get_zone_kind(zone_id) == "room" and path.size() >= 5 and (best.is_empty() or path.size() < best.size()):
			best = path
	return best


func _at_start(main2d: Node, hero: Player) -> void:
	var rm: RoomManager = main2d.room_manager
	hero.set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)


func _check_zone_on_the_way() -> void:
	var main2d := _main2d()
	var rm: RoomManager = main2d.room_manager
	var path := _long_path(main2d)
	_expect(path.size() >= 5 and rm.get_zone_kind(path[1]) == "corridor" and rm.get_zone_kind(path[2]) == "room", "setup: path room-corridor-room-corridor-room (%s)" % [path])
	var hero: Player = main2d.heroes[0]
	hero.stats.max_hp = HUGE_HP
	hero.stats.current_hp = HUGE_HP
	_at_start(main2d, hero)

	var spawner: HazardSpawner = main2d.hazard_spawner
	if not spawner.traps.has(path[1]):
		spawner.arm(path[1])
	if spawner._theme == null:
		spawner._theme = main2d.floor_manager.theme()
	var loot: LootSpawner = main2d.loot_spawner
	var chest: Chest = loot.chests.get(path[2])
	if chest == null:
		chest = loot.spawn_chest(path[2], ARMOR)

	var seen: Array[String] = []
	var track := func(zone_id: String) -> void: seen.append(zone_id)
	hero.zone_changed.connect(track)
	await main2d.player_action_controller.move_heroes([hero] as Array[Player], path[-1])
	hero.zone_changed.disconnect(track)
	_expect(seen == path.slice(1), "zones crossed: %s, path: %s" % [seen, path.slice(1)])
	_expect(not spawner.traps.has(path[1]), "crossing a corridor must spring its trap")
	_expect(not chest.is_closed(), "crossing a room must open its chest")
	_expect(hero.current_zone_id == path[-1] and hero.global_position.distance_to(rm.get_center(path[-1])) < 1.0, "the walk still ends on the target's center")


func _check_carrier_falls_on_the_way() -> void:
	var main2d := _main2d()
	var rm: RoomManager = main2d.room_manager
	var path := _long_path(main2d)
	var hero: Player = main2d.heroes[0]
	main2d.heroes[1].stats.max_hp = HUGE_HP  # the ally keeps the run going
	main2d.heroes[1].stats.current_hp = HUGE_HP
	_at_start(main2d, hero)
	hero.is_carrying_nexo = true
	main2d.nexo.pick_up()

	var controller: PlayerActionController = main2d.player_action_controller
	controller.move_heroes([hero] as Array[Player], path[-1])
	var corridor_center := rm.get_center(path[1])
	var limit := Time.get_ticks_msec() + 5000
	while hero.global_position.distance_to(corridor_center) > 12.0 and Time.get_ticks_msec() < limit:
		await process_frame
	hero.stats.take_damage(HUGE_HP)
	await process_frame

	var fell_at := hero.global_position
	_expect(main2d.nexo.is_dropped() and main2d.nexo.drop_zone_id == path[1], "the Nexo must drop in the corridor (zone '%s', wanted '%s')" % [main2d.nexo.drop_zone_id, path[1]])
	await _seconds(0.5)
	_expect(hero.global_position.distance_to(fell_at) < 1.0, "a fallen hero must stop where it fell (slid %.0f px)" % hero.global_position.distance_to(fell_at))
	_expect(hero.current_zone_id == path[1], "a fallen hero stays in its zone ('%s')" % hero.current_zone_id)
	_expect(not controller.is_busy(hero) and not controller._action_in_flight, "a fallen hero releases its order")


# ---------------- 5. door scaling ----------------

func _check_door_scaling() -> void:
	var main2d := _main2d()
	var fm: FloorManager = main2d.floor_manager
	var em: EnemyManager = main2d.enemy_manager
	_long_path(main2d)  # every room revealed: dark spawn rooms exist
	fm.floor_index = 3
	fm.players = 4
	const DOORS := 5
	var wanted := fm.threat_enemy_count(DOORS)
	_expect(wanted > fm.config.door_roll.enemy_count(DOORS, 3), "setup: 4 players grow the count")
	var counts: Array[int] = []
	var track := func(_rooms: Array[RoomZone], count: int) -> void: counts.append(count)
	em.invasion_triggered.connect(track)
	for i in 200:  # the roll is random; one invasion is enough
		em._on_turn_advanced(DOORS)
		if not counts.is_empty():
			break
	em.invasion_triggered.disconnect(track)
	_expect(not counts.is_empty() and counts[0] == wanted, "door invasion count %s, PlayerScaling says %d" % [counts, wanted])


# ---------------- minors ----------------

## Trap and boss charge are hits like any other: passives and shields apply.
func _check_damage_paths() -> void:
	var main2d := _main2d()
	var rm: RoomManager = main2d.room_manager
	var path := _long_path(main2d)
	var hero: Player = main2d.heroes[0]
	hero.stats.max_hp = HUGE_HP
	hero.stats.current_hp = HUGE_HP
	hero.stats.damage_taken_mult = 0.5

	var spawner: HazardSpawner = main2d.hazard_spawner
	var theme: FloorTheme = FloorManager.DEFAULT_CONFIG.theme(3)
	spawner._theme = theme
	spawner.traps.erase(path[1])
	spawner.arm(path[1])
	var raw := maxi(1, roundi(theme.trap_damage * main2d.floor_manager.enemy_damage_multiplier()))
	var hp := hero.stats.current_hp
	hero.zone_changed.emit(path[1])
	_expect(hp - hero.stats.current_hp == hero.abilities.incoming_damage(raw), "trap should go through incoming_damage (%d, raw %d)" % [hp - hero.stats.current_hp, raw])

	var boss: Enemy = main2d.enemy_manager.spawn_boss(hero.current_zone_id, theme.boss)
	raw = maxi(1, roundi(boss.type.charge_damage * boss.dmg_multiplier))
	hp = hero.stats.current_hp
	boss.boss_brain._land_charge(hero.global_position, hero.current_zone_id, Color.WHITE)
	_expect(hp - hero.stats.current_hp == hero.abilities.incoming_damage(raw), "boss charge should go through incoming_damage (%d, raw %d)" % [hp - hero.stats.current_hp, raw])
	hero.stats.damage_taken_mult = 1.0


func _check_revived_selection() -> void:
	var main2d := _main2d()
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var id: String = b.stats.hero_id
	selection.set_selection([a.stats.hero_id, id] as Array[String])
	selection.assign_group(1)
	resources.add_resource("food", 200)
	b.stats.take_damage(HUGE_HP)
	_expect(not selection.is_selected(id), "a downed hero leaves the selection")
	_expect(not selection.get_group(1, true).has(id), "a downed hero is not recalled by its group")
	_expect(ps.revive_hero(id), "setup: revive")
	_expect(selection.is_selected(id), "a revived hero should be selected again if it was")
	_expect(selection.get_group(1, true).has(id), "a revived hero should be back in its groups")


## coop-12: clients only build puppets; the floor's boss must still get its bar.
func _check_boss_puppet() -> void:
	var main2d := _main2d()
	var em: EnemyManager = main2d.enemy_manager
	var fm: FloorManager = main2d.floor_manager
	fm.floor_index = 3
	var spawned: Array[Enemy] = []
	var track := func(enemy: Enemy) -> void: spawned.append(enemy)
	em.boss_spawned.connect(track)
	em.spawn_puppet(9001, fm.theme().boss.id, main2d.heroes[0].current_zone_id, main2d.heroes[0].global_position, 100)
	em.boss_spawned.disconnect(track)
	_expect(spawned.size() == 1 and spawned[0] == em.boss, "a boss puppet should announce the boss (HUD bar)")
	var plain := em.spawn_puppet(9002, "goblin", main2d.heroes[0].current_zone_id, main2d.heroes[0].global_position, 10)
	_expect(plain != em.boss, "a plain puppet is not the boss")


func _check_hint_under_sheet() -> void:
	var hud: HUDController = ManagerLocator.get_hud()
	_expect(hud._hint_panel.get_index() < hud.character_popup.get_index(), "hints must draw under the hero sheet")
