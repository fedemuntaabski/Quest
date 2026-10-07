class_name RunState
extends Object

## RunState (coop-12): the slow-changing state of a floor as plain data, captured
## on the host and applied on clients through the same game APIs (no side effects:
## reveal_room, set_powered, BuildingSlot.build, apply_state()). One serializer
## for the periodic resync, reconnection and the desync hash.


static func capture(main2d: Node) -> Dictionary:
	var rm: RoomManager = main2d.room_manager
	var revealed := []
	for group_id in rm.get_group_ids():
		if rm.is_group_revealed(group_id):
			revealed.append(group_id)
	revealed.sort()
	var power := {}
	var modules := {}
	var zone_ids: Array = rm.get_zone_ids()
	zone_ids.sort()
	for zone_id: String in zone_ids:
		var zone := rm.get_zone_node(zone_id)
		if zone == null or zone.kind != "room":
			continue
		if zone.is_powered:
			power[zone_id] = zone.get_power_paid()
		var i := 0
		while zone.get_slot(i) != null:
			var slot := zone.get_slot(i)
			if not slot.is_empty() and is_instance_valid(slot.built_module):
				var m := slot.built_module as Module
				modules["%s#%d" % [zone_id, i]] = [int(m.module_type), m.current_hp]
			i += 1
	var gs := ManagerLocator.get_game_session()
	var nexo: Nexo = main2d.nexo
	var carrier := ""
	for hero in ManagerLocator.get_heroes():
		if hero.is_carrying_nexo:
			carrier = hero.stats.hero_id
	return {
		"floor": main2d.floor_manager.floor_index,
		"turn": main2d.door_turn_system.current_turn,
		"res": ManagerLocator.get_resource_manager().get_state(),
		"inv": ManagerLocator.get_party_inventory().get_state(),
		"stats": ManagerLocator.get_player_stats().get_run_state(),
		"revealed": revealed,
		"power": power,
		"modules": modules,
		"chests": _keys_where(main2d.loot_spawner.chests, func(c: Chest) -> bool: return not c.is_closed()),
		"cages": _keys_where(main2d.prisoner_spawner.cages, func(c: PrisonerCage) -> bool: return c.is_freed),
		"altars": _keys_where(main2d.altars, func(a: AltarShrine) -> bool: return a.is_used),
		"recruited": gs.recruited_ids.duplicate() if gs else [],
		"lost": gs.lost_ids.duplicate() if gs else [],
		"nexo": [nexo.current_hp, carrier, nexo.drop_zone_id, nexo.global_position],
		"extraction": [int(main2d.extraction_manager.current_phase), main2d.extraction_manager.stage],
	}


static func _keys_where(dict: Dictionary, pred: Callable) -> Array:
	var out := []
	for key in dict:
		if is_instance_valid(dict[key]) and pred.call(dict[key]):
			out.append(key)
	out.sort()
	return out


## Order-independent hash of a captured state (desync check).
static func state_hash(d: Dictionary) -> int:
	return hash(var_to_str(d))


## Client: makes the local floor match `d`. Idempotent; only differences act.
static func apply(main2d: Node, d: Dictionary) -> void:
	var rm: RoomManager = main2d.room_manager
	ManagerLocator.get_resource_manager().apply_state(d.get("res", {}))
	var gs := ManagerLocator.get_game_session()
	if gs:
		gs.lost_ids.assign(d.get("lost", []))
		for id: String in d.get("recruited", []):
			if not gs.recruited_ids.has(id):
				main2d.recruit_hero(id, rm.get_start_zone_id())  # snapshots place it
	main2d.door_turn_system.current_turn = int(d.get("turn", 0))

	var revealed_any := false
	for group_id: String in d.get("revealed", []):
		if not rm.is_group_revealed(group_id):
			var door := rm.get_door_for_group(group_id)
			if door:
				door.disable_door()
			main2d.door_turn_system.reveal_room(group_id)
			revealed_any = true
	if revealed_any:
		rm.refresh_door_visibility()

	var power: Dictionary = d.get("power", {})
	var modules: Dictionary = d.get("modules", {})
	for zone_id: String in rm.get_zone_ids():
		var zone := rm.get_zone_node(zone_id)
		if zone == null or zone.kind != "room":
			continue
		zone.apply_power(power.has(zone_id), int(power.get(zone_id, 0)))
		var i := 0
		while zone.get_slot(i) != null:
			_apply_slot(zone.get_slot(i), modules.get("%s#%d" % [zone_id, i]))
			i += 1

	ManagerLocator.get_party_inventory().apply_state(d.get("inv", {}))
	ManagerLocator.get_player_stats().apply_run_state(d.get("stats", {}))
	for zone_id in d.get("chests", []):
		var chest: Chest = main2d.loot_spawner.chests.get(zone_id)
		if chest and chest.is_closed():
			chest.show_open()
	for zone_id in d.get("cages", []):
		var cage: PrisonerCage = main2d.prisoner_spawner.cages.get(zone_id)
		if cage:
			cage.mark_freed()
	for zone_id in d.get("altars", []):
		var altar: AltarShrine = main2d.altars.get(zone_id)
		if altar and not altar.is_used:
			altar.is_used = true
			altar.queue_redraw()
	_apply_nexo(main2d, d.get("nexo", []))
	var ex: Array = d.get("extraction", [0, 0])
	if int(ex[0]) == ExtractionManager.Phase.EXTRACTION:
		main2d.extraction_manager.start_extraction()  # timers stay off on a client
	main2d.extraction_manager.apply_stage(int(ex[1]))


static func _apply_slot(slot: BuildingSlot, entry: Variant) -> void:
	if entry == null:
		if not slot.is_empty() and is_instance_valid(slot.built_module):
			(slot.built_module as Module).die()
		return
	var type := int(entry[0])
	if not slot.is_empty() and is_instance_valid(slot.built_module) and int(slot.built_module.module_type) != type:
		(slot.built_module as Module).die()
		return  # rebuilt on the next apply, once the slot freed itself
	var module := slot.build(type as Module.ModuleType)
	if module and module.current_hp != int(entry[1]):
		module.current_hp = int(entry[1])
		module.hp_changed.emit(module.current_hp, module.max_hp)
		module._update_bar()


static func _apply_nexo(main2d: Node, n: Array) -> void:
	if n.size() < 4:
		return
	var nexo: Nexo = main2d.nexo
	var hp := int(n[0])
	if hp < nexo.current_hp:
		nexo.take_damage(nexo.current_hp - hp)  # flash + cracks; `destroyed` is ignored on clients
	var carrier: String = n[1]
	for hero in ManagerLocator.get_heroes():
		hero.is_carrying_nexo = hero.stats.hero_id == carrier
	if carrier != "" and not nexo.is_carried():
		nexo.pick_up()
	elif carrier == "" and String(n[2]) != "" and not nexo.is_dropped():
		nexo.drop_at(n[2], n[3])
