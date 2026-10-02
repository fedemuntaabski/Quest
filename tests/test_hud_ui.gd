extends SceneTree

## Headless checks for the session-6 HUD logic (no rendering needed):
## HealthBarStyle thresholds, UpgradeConfig cost curve/bonuses, PlayerStats
## hero level-ups (session 7: spend Comida, all stats at once, cap, attack →
## hitbox values), per-turn yield, Module effect text, HUD bottom bar (resources
## + build entry, armed-only build flow with ghost/reasons/hotkeys/Esc — session
## 8), tactical pause / right-click move / close on death-victory (session 9),
## research (session 10: locks, prerequisites, bonuses, panel, floor/run
## lifetime) and popup wiring over a live Main2d. Session 12: runs a 1-hero
## party (PartyConfig.party_size 1) = the single-hero regression; the
## multi-hero checks live in test_party.gd.
##   godot --headless --path . --script res://tests/test_hud_ui.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/HUD.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	_check_health_style()
	_check_upgrade_config()
	_check_module_text()
	await _check_live()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_hud_ui: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_health_style() -> void:
	var style := load("res://resources/ui/health_bar_style.tres") as HealthBarStyle
	_expect(style.color_for(1.0) == style.high_color, "100% should be green")
	_expect(style.color_for(0.61) == style.high_color, "61% should be green")
	_expect(style.color_for(0.6) == style.mid_color, "60% should be yellow")
	_expect(style.color_for(0.3) == style.mid_color, "30% should be yellow")
	_expect(style.color_for(0.29) == style.low_color, "29% should be red")
	_expect(style.color_for(0.0) == style.low_color, "0% should be red")
	_expect(is_equal_approx(HealthBarStyle.ratio_of(16, 32), 0.5), "ratio_of(16, 32)")
	_expect(HealthBarStyle.ratio_of(5, 0) == 0.0, "ratio_of with max 0")
	_expect(HealthBarStyle.ratio_of(40, 32) == 1.0, "ratio_of clamps to 1")


func _check_upgrade_config() -> void:
	var cfg := load("res://resources/upgrades/run_upgrade_config.tres") as UpgradeConfig
	_expect(cfg.cost_resource == "food", "level-ups should cost food")
	var costs: Array[int] = []
	for level in cfg.max_level:
		costs.append(cfg.get_cost(level))
	_expect(costs == [8, 11, 16, 22, 31], "cost curve %s" % [costs])
	_expect(not cfg.is_maxed(cfg.max_level - 1) and cfg.is_maxed(cfg.max_level), "is_maxed boundary")
	_expect(cfg.damage_at(3, 2) == 5, "damage_at(3, 2)")
	_expect(is_equal_approx(cfg.interval_at(1.0, 3), maxf(cfg.min_attack_interval, 1.0 - cfg.attack_speed_per_level * 3)), "interval_at(1.0, 3) follows attack_speed_per_level")
	_expect(is_equal_approx(cfg.interval_at(1.0, 50), cfg.min_attack_interval), "interval floor")


func _check_module_text() -> void:
	_expect(Module.describe_effect(Module.ModuleType.GENERATOR_SCIENCE) == "+3 Ciencia por turno", "generator effect text: %s" % Module.describe_effect(Module.ModuleType.GENERATOR_SCIENCE))
	_expect(Module.describe_effect(Module.ModuleType.TRAP) == "Ralentiza 50% durante 3 s", "trap effect text: %s" % Module.describe_effect(Module.ModuleType.TRAP))
	for type in Module.CATALOG:
		_expect(Module.DESCRIPTIONS.has(type), "missing description for %s" % Module.ModuleType.keys()[type])


## Boots Main2d (hero registers with PlayerStats) + HUD like Main.gd does.
func _check_live() -> void:
	var resources := root.get_node("ResourceManager") as ResourceManager
	var ps := root.get_node("PlayerStats")
	resources.reset_resources(15, 15, 10, 20)
	resources.reset_research()
	ps.reset_run_upgrades()
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	main2d.party_config = main2d.party_config.duplicate()
	main2d.party_config.party_size = 1
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame

	_expect(main2d.heroes.size() == 1 and ps.get_hero_ids().size() == 1, "party_size 1 must spawn one hero")
	var stats: CharacterStats = ps.stats
	var player := main2d.get_tree().get_first_node_in_group("player") as Player
	_expect(stats != null and player != null, "hero not registered")
	if stats == null or player == null:
		return

	# Hitbox follows CharacterData, then upgrades.
	_expect(player.hitbox.damage == player.character_data.attack_damage, "hitbox damage %d != data %d" % [player.hitbox.damage, player.character_data.attack_damage])

	# Portrait: one, bar tracks HP.
	var portraits: Array = hud.portraits.get_children()
	_expect(portraits.size() == 1, "expected 1 portrait, got %d" % portraits.size())
	if portraits.size() == 1:
		var portrait := portraits[0] as HeroPortrait
		stats.take_damage(int(stats.max_hp * 0.8))
		_expect(portrait.target_ratio < 0.3, "portrait ratio %.2f after heavy damage" % portrait.target_ratio)
		stats.heal(stats.max_hp)
		_expect(is_equal_approx(portrait.target_ratio, 1.0), "portrait ratio after heal")
		portrait.portrait_clicked.emit(portrait)
		_expect(hud.character_popup.visible, "popup should open on portrait click")
		var level_button: Button = hud.character_popup._level_button
		_expect(level_button.text == "Subir de nivel (8 Comida)" and not level_button.disabled, "popup level button '%s'" % level_button.text)
		hud.character_popup.close()

	# Bottom bar: resources + build entry share one row, menu docked above it.
	_expect(hud.stats_hud_panel.get_parent().name == "BottomRow", "resource panel not in the bottom row")
	_expect(hud.building_menu.get_parent().name == "BottomBar", "building menu not docked in the bottom bar")
	_expect(hud.production_button != null and hud.defense_button != null, "bottom-bar build buttons missing")
	_expect(hud.floor_label != null and hud.floor_label.text.begins_with("Piso 1/"), "floor label not bound")
	var bottom_rect: Rect2 = hud.get_node("Control/BottomBar/BottomRow").get_global_rect()
	var minimap_rect: Rect2 = hud.get_node("Control/Minimap").get_global_rect()
	_expect(bottom_rect.size.x > 0 and not bottom_rect.intersects(minimap_rect), "bottom bar %s overlaps minimap %s" % [bottom_rect, minimap_rect])

	# Per-turn gain = base yield (no generators yet).
	_expect(resources.get_turn_yield("industry") == ResourceManager.BASE_YIELD_INDUSTRY, "industry turn yield")
	_expect(resources.get_turn_yield("dust") == 0, "dust turn yield")

	# Level-up (8 food, 15 available): every stat rises at once; the next (11) is short.
	var max_before := stats.max_hp
	var dmg_before := stats.attack_damage
	var interval_before := stats.attack_interval
	_expect(ps.level_up_hero(), "level up")
	_expect(resources.get_resource("food") == 7, "food after level up: %d" % resources.get_resource("food"))
	_expect(stats.max_hp == max_before + ps.run_upgrade_config.hp_per_level, "max hp %d after level up" % stats.max_hp)
	_expect(stats.attack_damage == dmg_before + 1 and player.hitbox.damage == stats.attack_damage, "damage level reached hitbox")
	_expect(stats.attack_interval < interval_before and is_equal_approx(player.hitbox.hit_interval, stats.attack_interval), "attack speed level reached hitbox")
	_expect(ps.get_hero_level() == 2 and ps.get_run_upgrade_level("damage") == 1, "hero level %d" % ps.get_hero_level())
	_expect(resources.get_resource("science") == 10, "level up must not spend science")
	_expect(not ps.get_level_up_preview()["affordable"], "second level should be unaffordable at 7 food")
	_expect(not ps.level_up_hero(), "level up with 7 food must fail")
	_expect(ps.get_hero_level() == 2, "failed level up must not change the level")
	resources.add_resource("food", 1000)
	_expect(ps.buy_run_upgrade("hp"), "compat buy_run_upgrade levels the hero up")
	while ps.level_up_hero():
		pass
	_expect(ps.get_hero_level() == 1 + ps.run_upgrade_config.max_level, "hero capped at max level")
	_expect(ps.get_level_up_preview()["maxed"], "level preview maxed")

	await _check_research(hud, main2d, resources)
	_check_building_menu(hud, main2d, resources)
	await _check_tactical_pause(hud, main2d, resources)
	_check_right_click(hud, main2d)
	_check_close_on_end(hud, main2d, ps)

	# New floor = new CharacterStats (same hero id): upgrades re-applied by refresh_stats().
	var fresh := CharacterStats.new()
	fresh.hero_id = stats.hero_id
	fresh.set_base_attack(3, 1.0)
	root.add_child(fresh)
	ps.register(fresh)
	_expect(fresh.max_hp == fresh.base_hp +ps.run_upgrade_config.hp_per_level * ps.run_level, "hp levels not re-applied on register: %d" % fresh.max_hp)
	_expect(fresh.attack_damage == 3 + ps.run_upgrade_config.max_level, "damage upgrade not re-applied on register")
	_expect(hud.portraits.get_child_count() == 1, "rebinding stats must reuse the portrait")

	ps.reset_run_upgrades()
	paused = false
	Engine.time_scale = 0.0  # leaving the scene must restore it (Main2d._exit_tree)
	hud.queue_free()
	main2d.queue_free()
	fresh.queue_free()
	await process_frame
	_expect(Engine.time_scale == 1.0, "time_scale %f after Main2d left the tree" % Engine.time_scale)
	await _check_research_lifetime(resources)


## Session 10: research survives the next floor (new Main2d + HUD, like
## Main.advance_floor) and is wiped by Main._begin_new_run (Retry / new run).
func _check_research_lifetime(resources: ResourceManager) -> void:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	_expect(resources.is_researched("science_generator") and resources.is_unlocked(Module.ModuleType.TURRET), "research must survive the next floor")
	hud.research_button.pressed.emit()
	var state := hud.research_panel._list.get_node("science_generator").find_child("State", true, false) as Label
	_expect(state.text == "Investigada", "next floor's panel should show the research as done")
	var main := Main.new()
	main._begin_new_run()
	main.free()
	_expect(not resources.is_researched("science_generator") and not resources.is_unlocked(Module.ModuleType.TURRET), "_begin_new_run (Retry) must reset research")
	state = hud.research_panel._list.get_node("science_generator").find_child("State", true, false) as Label
	_expect(state.text != "Investigada", "open panel must refresh on reset: '%s'" % state.text)
	hud.queue_free()
	main2d.queue_free()
	await process_frame


## Session 10: research as the Ciencia sink. Leaves science_generator +
## turret_plans researched (and no global bonus) for _check_building_menu.
func _check_research(hud: HUDController, main2d: Node, resources: ResourceManager) -> void:
	var cfg := resources.research_config
	_expect(cfg.entries.size() >= 6 and cfg.entries.size() <= 8, "research entries: %d" % cfg.entries.size())
	var tier2 := cfg.entries.filter(func(e: ResearchEntry) -> bool: return e.prerequisite != "")
	_expect(not tier2.is_empty() and tier2.all(func(e: ResearchEntry) -> bool:
		var pre := cfg.get_entry(e.prerequisite)
		return pre != null and pre.cost < e.cost), "T2 entries need an existing, cheaper prerequisite")
	var locked := Module.CATALOG.keys().filter(func(t: int) -> bool: return not resources.is_unlocked(t))
	_expect(locked.size() >= 2, "at least 2 modules locked at run start: %s" % [locked])
	for basic in [Module.ModuleType.GENERATOR_INDUSTRY, Module.ModuleType.GENERATOR_FOOD, Module.ModuleType.TRAP]:
		_expect(resources.is_unlocked(basic), "basic module %s must stay free" % Module.ModuleType.keys()[basic])

	var room_manager: RoomManager = main2d.room_manager
	var start := room_manager.get_zone_node(room_manager.get_start_zone_id())
	var major: BuildingSlot = null
	for slot in start.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MAJOR:
			major = slot
	var other: RoomZone = null
	for zone_id in room_manager.get_zone_ids():
		var zone := room_manager.get_zone_node(zone_id)
		if zone and zone.kind == "room" and zone != start:
			other = zone
			break
	_expect(major != null and other != null, "need the start MAJOR slot and a second room")
	if major == null or other == null:
		return

	# Locked module: padlock + "Requiere", hotkey/_arm refuse, the build gate holds.
	var menu: BuildingMenu = hud.building_menu
	resources.add_resource("industry", 100)
	hud.production_button.pressed.emit()
	var sci_card: Control = menu.options.get_child(2)
	_expect(sci_card.find_children("*", "StatIcon", true, false).any(func(i: StatIcon) -> bool: return i.icon_type == "lock"), "locked card needs a padlock")
	_expect(sci_card.tooltip_text.contains("Requiere: Instrumental arcano"), "locked card tooltip: %s" % sci_card.tooltip_text)
	_press_key(KEY_3)
	_expect(not menu.is_armed(), "hotkey must not arm a locked module")
	menu._arm(Module.ModuleType.GENERATOR_SCIENCE)
	_expect(not menu.is_armed(), "_arm must refuse a locked module")
	menu._armed_type = Module.ModuleType.GENERATOR_SCIENCE  # force it: the build path must still refuse
	var industry := resources.get_resource("industry")
	_expect(menu.get_block_reason(major) == "Requiere: Instrumental arcano", "locked reason: '%s'" % menu.get_block_reason(major))
	hud.open_building_menu(major)
	_expect(major.is_empty() and resources.get_resource("industry") == industry, "a locked module must not be built nor paid")
	menu.close_menu()

	# No research without Ciencia or without the prerequisite.
	resources.spend_resource("science", resources.get_resource("science"))
	_expect(not resources.can_research("science_generator") and not resources.research("science_generator"), "research with 0 science must fail")
	_expect(resources.get_research_block_reason("science_generator") == "Falta Ciencia", "no-science reason")
	resources.add_resource("science", 1000)
	_expect(resources.get_research_block_reason("generator_overclock") == "Requiere: Engranajes afinados", "prerequisite reason: '%s'" % resources.get_research_block_reason("generator_overclock"))
	_expect(not resources.research("generator_overclock") and resources.get_resource("science") == 1000, "T2 without its prerequisite must fail and spend nothing")

	# Panel at time_scale 0: open, research by button, only Ciencia is spent.
	Engine.time_scale = 0.0
	hud.research_button.pressed.emit()
	var panel := hud.research_panel
	_expect(panel.visible and not menu.visible and panel.get_parent().name == "BottomBar", "Investigar should open the docked panel")
	_expect(panel._list.get_child_count() == cfg.entries.size(), "one card per research")
	var before := {}
	for key in ResourceManager.KEYS:
		before[key] = resources.get_resource(key)
	(panel._list.get_node("science_generator").find_child("Research", true, false) as Button).pressed.emit()
	_expect(resources.is_researched("science_generator") and resources.is_unlocked(Module.ModuleType.GENERATOR_SCIENCE), "panel button should research at time_scale 0")
	for key in ResourceManager.KEYS:
		var expected: int = before[key] - (6 if key == "science" else 0)
		_expect(resources.get_resource(key) == expected, "research changed %s: %d != %d" % [key, resources.get_resource(key), expected])
	var sci_research := panel._list.get_node("science_generator")
	_expect((sci_research.find_child("State", true, false) as Label).text == "Investigada", "state after research")
	_expect((sci_research.find_child("Research", true, false) as Button).disabled, "done research can't be bought twice")
	_expect((panel._list.get_node("generator_overclock").find_child("State", true, false) as Label).text.begins_with("Requiere"), "T2 card shows its prerequisite")
	_expect(not resources.research("science_generator"), "research twice must fail")

	# Esc closes the panel and never reaches Main2d's pause toggle; right click closes too.
	var probe := InputProbe.new()
	root.add_child(probe)
	root.move_child(probe, hud.get_index())
	_press_key(KEY_ESCAPE)
	_expect(not panel.visible and not probe.got_esc and not paused, "Esc must close the research panel and be consumed")
	hud.research_button.pressed.emit()
	_push_mouse(MOUSE_BUTTON_RIGHT)
	_expect(not panel.visible and not probe.got_right, "right click must close the research panel (consumed)")
	probe.queue_free()
	_clear_handled()
	Engine.time_scale = 1.0

	# Unlocked now: the card arms.
	hud.production_button.pressed.emit()
	_press_key(KEY_3)
	_expect(menu.is_armed(), "Gen. Ciencia should arm once researched")
	menu.close_menu()

	# Light cost: 10 → 7 (paid and refunded at the discounted price).
	var dust := resources.get_resource("dust")
	_expect(RoomZone.get_power_cost() == RoomZone.POWER_COST, "base light cost")
	_expect(resources.research("dust_lenses"), "research dust_lenses")
	_expect(RoomZone.get_power_cost() == RoomZone.POWER_COST - 3, "discounted light cost %d" % RoomZone.get_power_cost())
	var hint := other.find_children("*", "EnergyButton", true, false)
	_expect(hint.is_empty() or (hint[0].get_node("Label") as Label).text.contains("(7 Polvo)"), "energy hint shows the discounted cost")
	other.try_power_up()
	_expect(other.is_powered and resources.get_resource("dust") == dust - 7, "lighting should cost 7 dust: %d" % (dust - resources.get_resource("dust")))
	other.power_down()
	_expect(resources.get_resource("dust") == dust, "switching off refunds what was paid")

	# Generator yield: +25% then +50% on the summed bonus.
	other.set_powered(true)
	var slots := other.find_children("*", "BuildingSlot", true, false)
	var other_major: BuildingSlot = slots.filter(func(b: BuildingSlot) -> bool: return b.slot_type == BuildingSlot.SlotType.MAJOR)[0]
	var other_minor: BuildingSlot = slots.filter(func(b: BuildingSlot) -> bool: return b.slot_type == BuildingSlot.SlotType.MINOR)[0]
	other_major.build(Module.ModuleType.GENERATOR_INDUSTRY)
	var base_industry := ResourceManager.BASE_YIELD_INDUSTRY
	_expect(resources.get_turn_yield("industry") == base_industry + 3, "generator yield without research")
	_expect(resources.research("generator_tuning") and resources.get_turn_yield("industry") == base_industry + 4, "+25%%: %d" % resources.get_turn_yield("industry"))
	_expect(resources.research("generator_overclock") and resources.get_turn_yield("industry") == base_industry + 5, "+50%%: %d" % resources.get_turn_yield("industry"))
	var industry_before := resources.get_resource("industry")
	resources.process_turn_production()
	_expect(resources.get_resource("industry") == industry_before + base_industry + 5, "boosted yield must be what the turn pays")

	# Turret damage: 15 → 25 per real shot.
	_expect(resources.research("turret_plans"), "research turret_plans")
	var turret := other_minor.build(Module.ModuleType.TURRET) as TurretModule
	var dummy := DamageDummy.new()
	root.add_child(dummy)
	turret.current_targets = [dummy]
	turret._on_fire_timer_timeout()
	_expect(dummy.taken == 15, "base turret shot %d" % dummy.taken)
	_expect(resources.research("turret_rifling"), "research turret_rifling")
	turret._on_fire_timer_timeout()
	_expect(dummy.taken == 15 + 25, "rifled turret shot %d" % (dummy.taken - 15))
	dummy.queue_free()

	# Discovery dust: +1 per room.
	var fm: FloorManager = main2d.floor_manager
	dust = resources.get_resource("dust")
	fm.on_room_discovered("test_room", [])
	var plain := resources.get_resource("dust") - dust
	_expect(resources.research("cartography"), "research cartography")
	dust = resources.get_resource("dust")
	fm.on_room_discovered("test_room", [])
	_expect(resources.get_resource("dust") - dust == plain + 1, "cartography: %d vs %d" % [resources.get_resource("dust") - dust, plain])

	# Back to "only the two unlocks" so the build-menu checks see plain numbers.
	other.set_powered(false)
	resources.reset_research()
	_expect(RoomZone.get_power_cost() == RoomZone.POWER_COST and not resources.is_unlocked(Module.ModuleType.TURRET), "reset_research wipes bonuses and unlocks")
	_expect(resources.research("science_generator") and resources.research("turret_plans"), "re-research the two unlocks")
	await process_frame


class DamageDummy extends Node2D:
	var taken := 0

	func take_damage(amount: int) -> void:
		taken += amount


## Session 8: building only through the bottom bar's armed mode. Unarmed slot
## clicks do nothing; Producción + key 3 arms Gen. Ciencia; ghost green/red
## with reasons; Esc cancels without pausing; Defensa → Torreta builds.
func _check_building_menu(hud: HUDController, main2d: Node, resources: ResourceManager) -> void:
	var room_manager: RoomManager = main2d.room_manager
	var room := room_manager.get_zone_node(room_manager.get_start_zone_id())
	room.set_powered(true)
	var major: BuildingSlot = null
	var minors: Array[BuildingSlot] = []
	for slot in room.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MAJOR:
			major = slot
		else:
			minors.append(slot)
	_expect(major != null and minors.size() == 2, "powered start room should have 1 MAJOR + 2 MINOR slots")
	if major == null or minors.size() != 2:
		return
	var menu: BuildingMenu = hud.building_menu

	# Unarmed: slots aren't pickable and a routed slot click does nothing.
	_expect(not major.input_pickable and not minors[0].input_pickable, "unarmed slots must not be pickable")
	var industry_before := resources.get_resource("industry")
	hud.open_building_menu(major)
	_expect(not menu.visible and major.is_empty() and resources.get_resource("industry") == industry_before, "slot click without an armed module must not open/build/spend")

	# Producción with 0 industry: 3 disabled cards, hotkey can't arm.
	resources.spend_resource("industry", resources.get_resource("industry"))
	hud.production_button.pressed.emit()
	_expect(menu.visible and menu.tabs.current_tab == 0, "Producción button should open the production tab")
	_expect(menu.options.get_child_count() == 3, "production tab shows %d cards" % menu.options.get_child_count())
	var buttons := menu.options.find_children("*", "Button", true, false)
	_expect(buttons.all(func(b: Button) -> bool: return b.disabled and b.text == "Elegir"), "cards must be 'Elegir' and disabled with 0 industry")
	_press_key(KEY_3)
	_expect(not menu.is_armed(), "hotkey must not arm an unaffordable card")
	resources.add_resource("industry", 100)  # resource_changed → cards rebuilt
	buttons = menu.options.find_children("*", "Button", true, false)
	_expect(buttons.size() == 3 and buttons.all(func(b: Button) -> bool: return not b.disabled), "cards must enable once affordable")
	_press_key(KEY_3)  # Gen. Ciencia
	_expect(menu.is_armed(), "key 3 should arm the third card")
	_expect(major.outline.default_color == BuildingSlot.HIGHLIGHT_OUTLINE, "armed generator should outline the free MAJOR slot")
	_expect(major.input_pickable and minors[0].input_pickable, "armed mode must make empty slots pickable")

	# Ghost: green on the MAJOR slot, red + reason on a MINOR one.
	major.mouse_entered.emit()
	_expect(major.get_ghost() != null and major.get_ghost().modulate == BuildingSlot.GHOST_OK, "green ghost over a valid slot")
	major.mouse_exited.emit()
	_expect(major.get_ghost() == null, "ghost cleared on mouse exit")
	minors[0].mouse_entered.emit()
	_expect(minors[0].get_ghost() != null and minors[0].get_ghost().modulate == BuildingSlot.GHOST_BLOCKED, "red ghost over a wrong-size slot")
	_expect(menu.get_block_reason(minors[0]).begins_with("Tamaño incorrecto"), "wrong-size reason: '%s'" % menu.get_block_reason(minors[0]))
	minors[0].mouse_exited.emit()
	var saved := resources.get_resource("industry")
	resources.spend_resource("industry", saved)
	_expect(menu.get_block_reason(major) == "Falta Industria", "no-industry reason: '%s'" % menu.get_block_reason(major))
	hud.open_building_menu(major)
	_expect(major.is_empty() and menu.is_armed(), "armed click without industry must not build nor disarm")
	resources.add_resource("industry", saved)
	room.set_powered(false)  # room_power_changed → re-arm
	_expect(menu.is_armed() and menu.get_block_reason(major) == "Sala apagada", "unlit-room reason: '%s'" % menu.get_block_reason(major))
	room.set_powered(true)

	# Armed click builds, spends, and leaves armed mode clean.
	var science_yield := resources.get_turn_yield("science")
	var gain_label: Label = hud.stat_panel.gain_labels["science"]
	industry_before = resources.get_resource("industry")
	hud.open_building_menu(major)
	_expect(not major.is_empty() and not menu.visible and not menu.is_armed(), "armed build did not happen")
	_expect(resources.get_resource("industry") < industry_before, "armed build did not spend industry")
	_expect(not minors[0].input_pickable and major.outline.default_color != BuildingSlot.HIGHLIGHT_OUTLINE, "armed state not cleared after build")
	_expect(resources.get_turn_yield("science") == science_yield + 3, "science yield after generator")
	_expect(gain_label.text == "+%d" % (science_yield + 3), "science gain label '%s'" % gain_label.text)

	# Esc cancels armed mode first — it must not reach Main2d's pause toggle.
	hud.defense_button.pressed.emit()
	_expect(menu.visible and menu.tabs.current_tab == 1, "Defensa button should open the defense tab")
	_press_key(KEY_1)  # Ballesta
	_expect(menu.is_armed(), "key 1 should arm the turret")
	# A probe sitting between Main2d and the HUD in input order tells whether
	# Esc got past the HUD.
	var probe := InputProbe.new()
	root.add_child(probe)
	root.move_child(probe, hud.get_index())
	_press_key(KEY_ESCAPE)
	_expect(not menu.is_armed() and not menu.visible, "Esc should cancel armed mode")
	_expect(not probe.got_esc and not paused, "Esc while armed must be consumed before Main2d's pause toggle")
	_press_key(KEY_ESCAPE)
	_expect(probe.got_esc, "Esc with the menu closed must pass through to the pause toggle")
	# That Esc opened the real pause menu (tree paused): Esc again resumes
	# (fades off so close() finishes synchronously).
	main2d.pause_menu.animate_transitions = false
	_expect(paused and main2d.pause_menu.is_open, "Esc with the menu closed should open the pause menu")
	_press_key(KEY_ESCAPE)
	_expect(not paused and not main2d.pause_menu.is_open, "Esc again should close the pause menu")
	probe.queue_free()

	# Defensa → Torreta → click a free MINOR slot builds there.
	hud.defense_button.pressed.emit()
	(menu.options.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
	_expect(minors.all(func(m: BuildingSlot) -> bool: return m.outline.default_color == BuildingSlot.HIGHLIGHT_OUTLINE), "armed turret should outline free minor slots")
	hud.open_building_menu(minors[0])
	_expect(not minors[0].is_empty() and not menu.visible and not menu.is_armed(), "armed turret build did not happen")
	_expect(minors[1].outline.default_color != BuildingSlot.HIGHLIGHT_OUTLINE, "other slot highlight not cleared")


## Session 9: Space = Engine.time_scale 0 ↔ 1. Camera pans/zooms on real
## time; building, arming, lighting and the hero popup work while frozen;
## the Esc pause runs at 1 and gives the tactical pause back on resume.
func _check_tactical_pause(hud: HUDController, main2d: Node, resources: ResourceManager) -> void:
	var camera := main2d.player.get_node("Camera2D") as GameCamera
	camera.config = camera.config.duplicate()
	camera.config.edge_scroll_enabled = false  # headless mouse sits in a corner
	_expect(hud.pause_label != null and not hud.pause_label.visible, "PAUSA label hidden while playing")
	_expect(hud.pause_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "PAUSA label must ignore the mouse")
	_press_key(KEY_SPACE)
	_expect(Engine.time_scale == 0.0 and main2d.is_tactically_paused(), "Space should freeze time_scale (%f)" % Engine.time_scale)
	_expect(hud.pause_label.visible, "PAUSA label should show in tactical pause")

	# Camera keeps panning and zooming at time_scale 0.
	var start := camera.global_position
	var zoom_before := camera.zoom.x
	camera.set_target_zoom(camera.config.zoom_max)
	Input.action_press("move_right")
	await create_timer(0.2, true, false, true).timeout
	Input.action_release("move_right")
	_expect(camera.global_position.x > start.x, "camera did not pan in tactical pause (%s -> %s)" % [start, camera.global_position])
	_expect(camera.zoom.x > zoom_before, "camera did not zoom in tactical pause (%f -> %f)" % [zoom_before, camera.zoom.x])
	camera.recenter()

	# Arm + build while frozen.
	var room: RoomZone = main2d.room_manager.get_zone_node(main2d.room_manager.get_start_zone_id())
	var free_minor: BuildingSlot = null
	for slot in room.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MINOR and slot.is_empty():
			free_minor = slot
	_expect(free_minor != null, "no free MINOR slot left for the pause build")
	if free_minor:
		var menu: BuildingMenu = hud.building_menu
		hud.defense_button.pressed.emit()
		_press_key(KEY_2)  # Trampa
		_expect(menu.is_armed(), "arming must work in tactical pause")
		var industry_before := resources.get_resource("industry")
		hud.open_building_menu(free_minor)
		_expect(not free_minor.is_empty() and resources.get_resource("industry") < industry_before, "building must work in tactical pause")

	# Light off/on (middle click) and the hero popup while frozen.
	resources.add_resource("dust", 20)
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	_clear_handled()
	room._on_input_event(root, middle, 0)
	_expect(not room.is_powered, "middle click should switch the room off in tactical pause")
	_clear_handled()
	room._on_input_event(root, middle, 0)
	_expect(room.is_powered, "middle click should light the room in tactical pause")
	var portrait := hud.portraits.get_child(0) as HeroPortrait
	portrait.portrait_clicked.emit(portrait)
	_expect(hud.character_popup.visible, "hero popup must open in tactical pause")
	hud.character_popup.close()

	# Esc pause: full pause at time_scale 1; resuming restores the tactical pause.
	var gsm := main2d.game_state_manager as GameStateManager
	gsm.request_pause()
	_expect(Engine.time_scale == 1.0 and not hud.pause_label.visible, "Esc pause should run at time_scale 1")
	_press_key(KEY_SPACE)
	_expect(main2d.is_tactically_paused() and Engine.time_scale == 1.0, "Space must not toggle while the pause menu is up")
	gsm.request_resume()
	_expect(Engine.time_scale == 0.0 and hud.pause_label.visible, "resume should give the tactical pause back")

	_press_key(KEY_SPACE)
	_expect(Engine.time_scale == 1.0 and not main2d.is_tactically_paused() and not hud.pause_label.visible, "Space again should resume")


## Session 9: unarmed right click on a room moves (same path as left click)
## and keeps the menu open; armed right click cancels and is consumed.
func _check_right_click(hud: HUDController, main2d: Node) -> void:
	var menu: BuildingMenu = hud.building_menu
	var room_manager: RoomManager = main2d.room_manager
	var room := room_manager.get_zone_node(room_manager.get_start_zone_id())
	var hits: Array[String] = []
	var on_click := func(zone_id: String) -> void: hits.append(zone_id)
	room_manager.zone_clicked.connect(on_click)
	# Probe between Main2d and the HUD in input order: sees what the HUD let through.
	var probe := InputProbe.new()
	root.add_child(probe)
	root.move_child(probe, hud.get_index())

	hud.production_button.pressed.emit()
	_push_mouse(MOUSE_BUTTON_RIGHT)
	_expect(menu.visible and probe.got_right, "unarmed right click must not close/consume (menu closes with Esc/outside click)")
	_clear_handled()
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	room._on_input_event(root, right, 0)
	_expect(hits == [room.zone_id], "unarmed right click should route to the move handler (%s)" % [hits])

	hud.defense_button.pressed.emit()
	_press_key(KEY_1)
	_expect(menu.is_armed(), "key 1 should arm for the right-click cancel")
	probe.got_right = false
	_push_mouse(MOUSE_BUTTON_RIGHT)
	_expect(not menu.is_armed() and not menu.visible, "armed right click should cancel")
	_expect(not probe.got_right, "armed right click must be consumed so it can't reach RoomZone picking")
	probe.queue_free()
	room_manager.zone_clicked.disconnect(on_click)


## Session 9 (pending since session 6): death and victory close the popup and
## the build menu; death also drops the tactical pause (overlays tween).
func _check_close_on_end(hud: HUDController, main2d: Node, ps: Node) -> void:
	var portrait := hud.portraits.get_child(0) as HeroPortrait
	var menu: BuildingMenu = hud.building_menu
	portrait.portrait_clicked.emit(portrait)
	hud.production_button.pressed.emit()
	(main2d.game_state_manager as GameStateManager).victory_entered.emit()
	_expect(not hud.character_popup.visible and not menu.visible, "victory should close popup and build menu")

	portrait.portrait_clicked.emit(portrait)
	hud.production_button.pressed.emit()
	_press_key(KEY_SPACE)
	_expect(Engine.time_scale == 0.0, "tactical pause before death")
	ps.player_died.emit()
	_expect(not hud.character_popup.visible and not menu.visible, "death should close popup and build menu")
	_expect(Engine.time_scale == 1.0 and not hud.pause_label.visible, "death should drop the tactical pause (%f)" % Engine.time_scale)


## Off-screen mouse press through the viewport (runs every _input, picks nothing).
func _push_mouse(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = Vector2(-10000, -10000)
	root.push_input(event)


class InputProbe extends Node:
	var got_esc := false
	var got_right := false

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			got_esc = true
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			got_right = true


## A pushed mouse press stays "handled" (queued for physics picking); a key
## release resets the flag before calling RoomZone._on_input_event directly.
func _clear_handled() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F24
	root.push_input(event)


## Real key press through the viewport (HUD _input runs before Main2d's).
func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)
