extends SceneTree

## Headless checks for the session-6 HUD logic (no rendering needed):
## HealthBarStyle thresholds, UpgradeConfig cost curve/bonuses, PlayerStats
## hero level-ups (session 7: spend Comida, all stats at once, cap, attack →
## hitbox values), per-turn yield, Module effect text, HUD bottom bar (resources
## + build entry, armed build flow) and popup wiring over a live Main2d.
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
	_expect(is_equal_approx(cfg.interval_at(1.0, 3), 0.7), "interval_at(1.0, 3)")
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
	ps.reset_run_upgrades()
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame

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

	_check_building_menu(hud, main2d.room_manager, resources)

	# New floor = new CharacterStats: upgrades re-applied by refresh_stats().
	var fresh := CharacterStats.new()
	fresh.set_base_attack(3, 1.0)
	root.add_child(fresh)
	ps.register(fresh)
	_expect(fresh.max_hp == ps.base_hp + ps.run_upgrade_config.hp_per_level * ps.run_level, "hp levels not re-applied on register: %d" % fresh.max_hp)
	_expect(fresh.attack_damage == 3 + ps.run_upgrade_config.max_level, "damage upgrade not re-applied on register")
	_expect(hud.portraits.get_child_count() == 1, "rebinding stats must reuse the portrait")

	ps.reset_run_upgrades()
	hud.queue_free()
	main2d.queue_free()
	fresh.queue_free()
	await process_frame


## Powers the start room, opens the menu on its MAJOR slot, checks tab/cards/
## highlight/affordability and builds a Gen. Ciencia (gain label follows).
func _check_building_menu(hud: HUDController, room_manager: RoomManager, resources: ResourceManager) -> void:
	var room := room_manager.get_zone_node(room_manager.get_start_zone_id())
	room.set_powered(true)
	var major: BuildingSlot = null
	for slot in room.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MAJOR:
			major = slot
	_expect(major != null, "powered start room has no MAJOR slot")
	if major == null:
		return
	var menu: BuildingMenu = hud.building_menu
	resources.spend_resource("industry", resources.get_resource("industry"))
	hud.open_building_menu(major)
	_expect(menu.visible and menu.tabs.current_tab == 0, "MAJOR slot should open on Producción")
	_expect(major.outline.default_color == BuildingSlot.HIGHLIGHT_OUTLINE, "chosen slot not highlighted")
	_expect(menu.options.get_child_count() == 3, "production tab shows %d cards" % menu.options.get_child_count())
	var buttons := menu.options.find_children("*", "Button", true, false)
	_expect(buttons.all(func(b: Button) -> bool: return b.disabled), "cards must be disabled with 0 industry")
	resources.add_resource("industry", 100)  # resource_changed → cards rebuilt
	buttons = menu.options.find_children("*", "Button", true, false)
	_expect(buttons.size() == 3 and buttons.all(func(b: Button) -> bool: return not b.disabled), "cards must enable once affordable")
	menu.tabs.current_tab = 1
	buttons = menu.options.find_children("*", "Button", true, false)
	_expect(buttons.size() == 2 and buttons.all(func(b: Button) -> bool: return b.disabled), "defense cards must be disabled on a MAJOR slot")
	menu.tabs.current_tab = 0
	var science_yield := resources.get_turn_yield("science")
	var gain_label: Label = hud.stat_panel.gain_labels["science"]
	(menu.options.find_children("*", "Button", true, false)[2] as Button).pressed.emit()  # Gen. Ciencia
	_expect(not menu.visible and not major.is_empty(), "build did not happen")
	_expect(major.outline.default_color != BuildingSlot.HIGHLIGHT_OUTLINE, "highlight not cleared on close")
	_expect(resources.get_turn_yield("science") == science_yield + 3, "science yield after generator")
	_expect(gain_label.text == "+%d" % (science_yield + 3), "science gain label '%s'" % gain_label.text)

	# Bottom-bar flow: Defensa → "Elegir" Torreta arms it and outlines both free
	# MINOR slots; clicking one builds there.
	hud.defense_button.pressed.emit()
	_expect(menu.visible and menu.tabs.current_tab == 1, "Defensa button should open the defense tab")
	var picks := menu.options.find_children("*", "Button", true, false)
	_expect(picks.size() == 2 and picks.all(func(b: Button) -> bool: return not b.disabled and b.text == "Elegir"), "category cards should be 'Elegir' and enabled")
	(picks[0] as Button).pressed.emit()
	_expect(menu.is_armed(), "picking a card should arm the module")
	var minors: Array[BuildingSlot] = []
	for slot in room.find_children("*", "BuildingSlot", true, false):
		if slot.slot_type == BuildingSlot.SlotType.MINOR:
			minors.append(slot)
	_expect(minors.size() == 2 and minors.all(func(m: BuildingSlot) -> bool: return m.outline.default_color == BuildingSlot.HIGHLIGHT_OUTLINE), "armed module should outline free minor slots")
	var industry_before := resources.get_resource("industry")
	hud.open_building_menu(minors[0])
	_expect(not minors[0].is_empty() and not menu.visible and not menu.is_armed(), "armed build did not happen")
	_expect(resources.get_resource("industry") < industry_before, "armed build did not spend industry")
	_expect(minors[1].outline.default_color != BuildingSlot.HIGHLIGHT_OUTLINE, "other slot highlight not cleared")

