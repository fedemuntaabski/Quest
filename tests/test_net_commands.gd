extends SceneTree

## coop-12 phase 3: NetCommands validation on the host, over a live Main2d
## (fallback map). Every command with a valid case and refused cases: unknown
## command / malformed args, a hero owned by another player, no resources, a
## door nobody stands next to, an occupied slot, blocked research, the rate
## limit, and a client process refusing to mutate anything by itself.
##   godot --headless --path . --script res://tests/test_net_commands.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const OTHER := 2  # a second player's peer id

var failures: Array[String] = []
var cmds: CoopCommands
var net: CoopSession
var rm: ResourceManager
var ps: Node


func _initialize() -> void:
	await process_frame
	cmds = root.get_node("NetCommands") as CoopCommands
	net = root.get_node("NetSession") as CoopSession
	rm = root.get_node("ResourceManager") as ResourceManager
	ps = root.get_node("PlayerStats")
	rm.reset_resources(0, 0, 0, 0)
	rm.reset_research()
	ps.reset_run_upgrades()

	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()

	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var ida := a.stats.hero_id
	var idb := b.stats.hero_id
	# A co-op host where hero A is ours (peer 1) and hero B belongs to peer 2.
	net.mode = CoopSession.Mode.HOST
	net.hero_owner = {ida: 1, idb: OTHER}

	await _check_malformed(ida)
	await _check_doors_and_moves(main2d, a, ida, idb)
	await _check_power_and_build(main2d)
	await _check_stats(a, ida, idb)
	await _check_items(ida)
	await _check_rate_limit()
	_check_client_gate()

	net.mode = CoopSession.Mode.OFFLINE
	net.hero_owner.clear()
	main2d.queue_free()
	await process_frame
	for f in failures:
		printerr("FAIL: ", f)
	print("test_net_commands: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _run(sender: int, cmd: String, args: Dictionary) -> String:
	cmds._rate.clear()
	return await cmds.run_command(sender, cmd, args)


func _check_malformed(ida: String) -> void:
	_expect(await _run(1, "nope", {}) == CoopCommands.INVALID, "unknown command")
	_expect(await _run(1, "move", {"heroes": [ida], "zone": 5}) == CoopCommands.INVALID, "zone must be a String")
	_expect(await _run(1, "move", {"zone": "start_room"}) == CoopCommands.INVALID, "move without heroes")
	_expect(await _run(1, "move", {"heroes": [3], "zone": "start_room"}) == CoopCommands.INVALID, "hero ids must be Strings")
	_expect(await _run(1, "build", {"zone": "start_room"}) == CoopCommands.INVALID, "build without slot/type")
	_expect(await _run(1, "build", {"zone": "start_room", "slot": 0, "type": 99}) == CoopCommands.INVALID, "unknown module type")
	_expect(await _run(1, "equip", {"hero": ida, "item": "no_such_item"}) == CoopCommands.INVALID, "unknown item")
	_expect(await _run(1, "open_door", {"door": "nope", "heroes": [ida]}) == CoopCommands.INVALID, "unknown door")


func _check_doors_and_moves(main2d: Node, a: Player, ida: String, idb: String) -> void:
	var room_manager: RoomManager = main2d.room_manager
	var start := room_manager.get_start_zone_id()
	var near: Door = null
	var far: Door = null
	for door in room_manager.get_all_doors():
		if door.get_target_room_for(start) != "":
			near = door
		elif not room_manager.is_zone_revealed(door.from_zone_id):
			far = door
	_expect(near != null and far != null, "fallback map has a near and a far door")
	if near == null or far == null:
		return
	_expect(await _run(OTHER, "open_door", {"door": near.door_id, "heroes": [ida]}) == CoopCommands.NOT_YOURS, "another player's hero can't open")
	_expect(await _run(1, "open_door", {"door": far.door_id, "heroes": [ida]}) == "Puerta sin descubrir", "a hidden door is refused")
	var turn: int = main2d.door_turn_system.current_turn
	_expect(await _run(1, "open_door", {"door": near.door_id, "heroes": [ida]}) == "", "own hero opens the near door")
	_expect(main2d.door_turn_system.current_turn == turn + 1, "opening ticked the turn")
	_expect(await _run(1, "open_door", {"door": near.door_id, "heroes": [ida]}) == "La puerta ya está abierta", "an open door is refused")
	_expect(await _run(OTHER, "move", {"heroes": [ida], "zone": start}) == CoopCommands.NOT_YOURS, "can't move another player's hero")
	var hidden := ""
	for zone_id in room_manager.get_zone_ids():
		if not room_manager.is_zone_revealed(zone_id):
			hidden = zone_id
	_expect(await _run(1, "move", {"heroes": [ida], "zone": hidden}) == "Sala sin descubrir", "can't walk into fog")
	_expect(await _run(1, "move", {"heroes": [ida], "zone": start}) == "", "own hero walks back")
	_expect(a.current_zone_id == start, "hero A is back in the start room")
	_expect(await _run(OTHER, "move", {"heroes": [idb], "zone": start}) == "", "peer 2 moves its own hero")


func _check_power_and_build(main2d: Node) -> void:
	var room_manager: RoomManager = main2d.room_manager
	var start := room_manager.get_start_zone_id()
	var dark := ""
	for zone_id in room_manager.get_zone_ids():
		if zone_id != start and room_manager.get_zone_kind(zone_id) == "room" and room_manager.is_zone_revealed(zone_id):
			dark = zone_id
	_expect(dark != "", "a discovered dark room exists")
	rm.reset_resources(0, 0, 0, 0)
	_expect(await _run(OTHER, "toggle_power", {"zone": dark}) == "Polvo insuficiente", "lighting needs dust")
	_expect(await _run(OTHER, "build", {"zone": dark, "slot": 0, "type": int(Module.ModuleType.FORJA)}) != "", "can't build in a dark room")
	rm.reset_resources(0, 0, 0, 100)
	_expect(await _run(OTHER, "toggle_power", {"zone": dark}) == "", "any player can light a room")
	_expect(room_manager.get_zone_node(dark).is_powered, "the room is lit")
	var forja := int(Module.ModuleType.FORJA)
	_expect(await _run(1, "build", {"zone": start, "slot": 0, "type": forja}) == "Falta Industria", "building needs Industria")
	rm.reset_resources(200, 0, 0, 0)
	_expect(await _run(OTHER, "build", {"zone": start, "slot": 0, "type": forja}) == "", "any player can build")
	_expect(not room_manager.get_zone_node(start).get_slot(0).is_empty(), "the module is built")
	_expect(rm.get_resource("industry") < 200, "the build was paid")
	_expect(await _run(1, "build", {"zone": start, "slot": 0, "type": forja}) == "Slot ocupado", "occupied slot refused")
	_expect(String(await _run(1, "build", {"zone": start, "slot": 1, "type": forja})).begins_with("Tamaño"), "a major module in a minor slot is refused")
	_expect(await _run(1, "repair", {"zone": start, "slot": 0}) == "No está dañado", "undamaged module can't be repaired")
	var entry := rm.research_config.entries[0]
	_expect(await _run(OTHER, "research", {"id": entry.id}) == "Construí un Scriptorium", "research needs a Scriptorium")
	_expect(await _run(1, "research", {"id": "no_such"}) == "Investigación desconocida", "unknown research refused")
	_expect(await _run(1, "demolish", {"zone": start, "slot": 0}) == "", "demolish works")
	await process_frame
	_expect(room_manager.get_zone_node(start).get_slot(0).is_empty(), "the slot is free again")


func _check_stats(a: Player, ida: String, idb: String) -> void:
	rm.reset_resources(0, 0, 0, 0)
	_expect(await _run(1, "level_up", {"hero": ida}) == "Falta Comida", "level up needs Comida")
	_expect(await _run(OTHER, "level_up", {"hero": ida}) == CoopCommands.NOT_YOURS, "can't level another player's hero")
	rm.reset_resources(0, 500, 0, 0)
	_expect(await _run(1, "level_up", {"hero": ida}) == "", "level up own hero")
	_expect(ps.get_hero_level(ida) == 2, "hero A reached level 2")
	a.stats.heal(a.stats.max_hp)
	_expect(await _run(OTHER, "heal", {"hero": ida}) == "Nada que curar", "nothing to heal at full HP")
	a.stats.take_damage(10)
	_expect(await _run(OTHER, "heal", {"hero": ida}) == "", "any player may heal an ally")
	_expect(a.stats.current_hp == a.stats.max_hp, "healed to full")
	_expect(await _run(OTHER, "revive", {"hero": idb}) == "No está caído", "revive needs a downed hero")
	_expect(await _run(1, "choose_perk", {"hero": ida, "perk": "nope"}) == "Mejora no disponible", "unknown perk refused")


func _check_items(ida: String) -> void:
	var inv := root.get_node("PartyInventory") as PartyInventory
	inv.reset()
	var weapon: ItemData = null
	for item in ItemCatalog.get_default().items:
		if item.slot == ItemData.Slot.WEAPON and weapon == null:
			weapon = item
	inv.add_item(weapon)
	_expect(await _run(OTHER, "equip", {"hero": ida, "item": weapon.id}) == CoopCommands.NOT_YOURS, "can't equip another player's hero")
	_expect(await _run(1, "equip", {"hero": ida, "item": weapon.id}) == "", "equip from the shared stash")
	_expect(inv.get_equipped(ida, ItemData.Slot.WEAPON).has(weapon), "weapon equipped")
	_expect(await _run(1, "unequip", {"hero": ida, "slot": int(ItemData.Slot.WEAPON), "index": 0}) == "", "unequip")
	_expect(await _run(1, "unequip", {"hero": ida, "slot": 77}) == CoopCommands.INVALID, "unknown slot refused")
	_expect(await _run(1, "consume", {"hero": ida, "index": 0}) != "", "no consumable to use")
	inv.reset()


func _check_rate_limit() -> void:
	cmds._rate.clear()
	var refused := false
	for i in net.config.max_cmds_per_sec + 2:
		if await cmds.run_command(3, "nope", {}) == "Demasiadas órdenes":
			refused = true
	_expect(refused, "a flood of commands is rate limited")
	cmds._rate.clear()


## A client never mutates by itself: the authority guards refuse.
func _check_client_gate() -> void:
	rm.reset_resources(5, 5, 5, 5)
	net.mode = CoopSession.Mode.CLIENT
	_expect(not Net.is_authority(), "client is not the authority")
	rm.add_resource("dust", 10)
	_expect(not rm.spend_resource("dust", 1), "client can't spend")
	_expect(rm.get_resource("dust") == 5, "client can't add resources")
	net.mode = CoopSession.Mode.HOST
