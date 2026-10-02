extends SceneTree

## Session impl-6, fase 4: bestiary.
##   - tiers (seen -> killed -> mastered) and the unlock signal, once per tier
##   - kills count only for deaths by damage, never for a node freed (floor change)
##   - ConfigFile round trip, unknown ids ignored, two slots independent, legacy keys dropped
##   - detail text unlocks by tier; 20 types in bestiary_order
##   - PauseMenu opens/closes the panel (Main2d complete), Esc closes only the panel
##   godot --headless --path . --script res://tests/test_bestiary.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const SLOT_A := 97
const SLOT_B := 98

var failures: Array[String] = []
var _svc: BestiaryService
var _save: Node


func _initialize() -> void:
	_svc = root.get_node("BestiaryService")
	_save = root.get_node("SaveManager")
	_svc.reset()
	_test_entry_and_tiers()
	_test_roundtrip()
	_test_detail_text()
	await _test_slots()
	await _test_kills_by_damage()
	await _test_pause_menu()
	_svc.reset()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_bestiary: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _type(id: String) -> EnemyType:
	return load("res://resources/enemies/%s.tres" % id) as EnemyType


func _test_entry_and_tiers() -> void:
	var ordered := _svc.get_all_ordered()
	_expect(ordered.size() == 20, "get_all_ordered: %d types, expected 20" % ordered.size())
	for i in range(1, ordered.size()):
		_expect(ordered[i - 1].bestiary_order <= ordered[i].bestiary_order, "types not ordered by bestiary_order")
	for type in ordered:
		_expect(type.description != "" and type.lore != "", "%s: missing bestiary text" % type.id)

	var goblin := _type("goblin")
	var unlocked: Array = []
	_svc.entry_unlocked.connect(func(id: String, tier: BestiaryEntry.Tier) -> void: unlocked.append([id, tier]))
	_expect(_svc.get_tier("goblin") == BestiaryEntry.Tier.UNKNOWN and _svc.get_entry("nope").tier() == BestiaryEntry.Tier.UNKNOWN, "fresh entries are UNKNOWN")
	_svc.register_seen(goblin, 2)
	_svc.register_seen(goblin, 3)
	var entry := _svc.get_entry("goblin")
	_expect(entry.tier() == BestiaryEntry.Tier.SEEN and entry.seen_count == 2 and entry.first_seen_floor == 2 and entry.max_floor_seen == 3, "seen: %s" % [entry.to_dict()])
	_svc.register_kill(goblin, 3)
	_expect(_svc.get_tier("goblin") == BestiaryEntry.Tier.KILLED and entry.first_kill_floor == 3, "one kill -> KILLED")
	_svc.register_kill(goblin, 3)
	_expect(_svc.get_tier("goblin") == BestiaryEntry.Tier.KILLED, "two kills are still KILLED")
	_svc.register_kill(goblin, 4)
	_expect(_svc.get_tier("goblin") == BestiaryEntry.Tier.MASTERED, "%d kills -> MASTERED" % BestiaryEntry.MASTER_KILLS)
	_expect(unlocked == [["goblin", BestiaryEntry.Tier.SEEN], ["goblin", BestiaryEntry.Tier.KILLED], ["goblin", BestiaryEntry.Tier.MASTERED]], "unlock signal once per tier: %s" % [unlocked])
	_expect(_svc.unlocked_count() == 1, "unlocked_count")
	# A kill of something never "seen" (e.g. spawned before the bestiary existed) still unlocks it.
	_svc.register_kill(_type("imp"), 1)
	_expect(_svc.get_tier("imp") == BestiaryEntry.Tier.KILLED, "kill without sight -> KILLED")


func _test_roundtrip() -> void:
	var cfg := ConfigFile.new()
	_svc.write_to(cfg)
	cfg.set_value("bestiary", "ghost_enemy", {"seen": 5, "kills": 5})
	cfg.set_value("bestiary", "skelet", "not a dictionary")
	var before := _svc.entries.duplicate()
	_svc.reset()
	_svc.read_from(cfg)
	_expect(_svc.entries.size() == before.size(), "round trip: %d entries, expected %d" % [_svc.entries.size(), before.size()])
	for id: String in before:
		_expect(_svc.get_entry(id).to_dict() == (before[id] as BestiaryEntry).to_dict(), "round trip changed '%s'" % id)
	_expect(not _svc.entries.has("ghost_enemy") and not _svc.entries.has("skelet"), "unknown id / malformed value must be ignored")
	_expect(int(cfg.get_value("bestiary", "version")) == BestiaryService.VERSION, "version written")


func _test_detail_text() -> void:
	var skelet := _type("skelet")
	var entry := BestiaryEntry.new("skelet")
	_expect(BestiaryPanel.detail_text(skelet, entry).begins_with("Todavía no"), "UNKNOWN text")
	entry.seen_count = 1
	entry.first_seen_floor = 1
	entry.max_floor_seen = 1
	var seen := BestiaryPanel.detail_text(skelet, entry)
	_expect(seen.contains("Cazador") and not seen.contains("Vida:"), "SEEN shows the behavior, no stats")
	entry.kill_count = 1
	var killed := BestiaryPanel.detail_text(skelet, entry)
	_expect(killed.contains("Vida:") and killed.contains(skelet.description) and not killed.contains("Daño a módulos"), "KILLED shows stats and description")
	entry.kill_count = BestiaryEntry.MASTER_KILLS
	var mastered := BestiaryPanel.detail_text(skelet, entry)
	_expect(mastered.contains("Daño a módulos") and mastered.contains("Rol:") and mastered.contains(skelet.lore), "MASTERED shows everything")


## Saves of two slots stay apart; legacy keys are dropped; autosave once a slot is loaded.
func _test_slots() -> void:
	for slot in [SLOT_A, SLOT_B]:
		_save.delete_save(slot)
	var old := ConfigFile.new()
	old.set_value("save_data", "run_cycle", 4)
	old.set_value("save_data", "post_victory_popup_pending", true)
	old.save(_save.get_save_path(SLOT_A))

	_svc.reset()
	_svc.slot = SLOT_A
	_svc.register_kill(_type("goblin"), 1)
	_save.save_game(SLOT_A)
	var cfg := ConfigFile.new()
	cfg.load(_save.get_save_path(SLOT_A))
	_expect(not cfg.has_section_key("save_data", "run_cycle") and not cfg.has_section_key("save_data", "post_victory_popup_pending"), "legacy keys dropped on save")
	_expect(cfg.has_section_key("bestiary", "goblin"), "bestiary written into slot A")

	# A slot that is not the loaded one is never overwritten with this slot's entries.
	_save.save_game(SLOT_B)
	cfg = ConfigFile.new()
	cfg.load(_save.get_save_path(SLOT_B))
	_expect(not cfg.has_section_key("bestiary", "goblin"), "slot B must not receive slot A's bestiary")

	_save.load_game(SLOT_B)
	_expect(_svc.unlocked_count() == 0 and _svc.slot == SLOT_B, "slot B starts empty")
	_save.load_game(SLOT_A)
	_expect(_svc.get_tier("goblin") == BestiaryEntry.Tier.KILLED, "slot A keeps its progress")
	_svc.register_seen(_type("skelet"), 2)
	await process_frame
	await process_frame
	cfg = ConfigFile.new()
	cfg.load(_save.get_save_path(SLOT_A))
	_expect(cfg.has_section_key("bestiary", "skelet"), "autosave after a change once a slot is loaded")

	_save.slot_loaded = false
	_save.current_slot = 1
	for slot in [SLOT_A, SLOT_B]:
		_save.delete_save(slot)
	_svc.reset()


func _boot() -> Node:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	return main2d


func _test_kills_by_damage() -> void:
	_svc.reset()
	var main2d := await _boot()
	var enemies: EnemyManager = main2d.enemy_manager
	var rm: RoomManager = main2d.room_manager
	var zone := rm.get_start_zone_id()
	var freed := enemies._spawn_enemy(zone, rm.get_center(zone))
	freed.ai_timer.stop()
	var freed_id := freed.type.id
	_expect(_svc.get_tier(freed_id) == BestiaryEntry.Tier.SEEN, "first spawn marks the type as seen")
	freed.queue_free()
	await process_frame
	_expect(_svc.get_entry(freed_id).kill_count == 0 and not is_instance_valid(freed), "a freed enemy is not a kill")

	var slain := enemies._spawn_enemy(zone, rm.get_center(zone))
	slain.ai_timer.stop()
	var slain_id := slain.type.id
	var kills_before := _svc.get_entry(slain_id).kill_count
	slain.take_damage(99999)
	_expect(_svc.get_entry(slain_id).kill_count == kills_before + 1, "a death by damage is a kill")

	# Changing floor frees every enemy: no kills.
	var kills := _total_kills()
	var left := enemies._spawn_enemy(zone, rm.get_center(zone))
	left.ai_timer.stop()
	main2d.queue_free()
	await process_frame
	await process_frame
	_expect(_total_kills() == kills, "freeing the floor must not count kills")
	_svc.reset()


func _total_kills() -> int:
	var total := 0
	for id: String in _svc.entries:
		total += (_svc.entries[id] as BestiaryEntry).kill_count
	return total


func _test_pause_menu() -> void:
	var main2d := await _boot()
	var menu: PauseMenu = main2d.pause_menu
	_expect(menu != null and menu.bestiary_panel != null and menu.bestiary_button != null, "PauseMenu lacks the bestiary button/panel")
	if menu == null or menu.bestiary_panel == null:
		main2d.queue_free()
		return
	menu.open()
	_expect(menu.is_open and paused and menu.pause_panel.visible and not menu.bestiary_panel.visible, "pause menu opens on the main panel")
	menu.bestiary_button.pressed.emit()
	_expect(menu.bestiary_panel.visible and not menu.pause_panel.visible, "BESTIARIO opens the panel")
	_expect(menu.bestiary_panel._items.size() == 20, "panel lists the 20 enemies")

	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	menu.bestiary_panel._input(esc)
	_expect(not menu.bestiary_panel.visible and menu.pause_panel.visible and menu.is_open, "Esc closes only the bestiary panel")
	menu.bestiary_button.pressed.emit()
	menu.close()
	await create_timer(0.6).timeout
	_expect(not menu.is_open and not menu.bestiary_panel.visible and not paused and Engine.time_scale == 1.0, "closing the menu closes the panel and resumes (time_scale %s)" % Engine.time_scale)
	main2d.queue_free()
	await process_frame
