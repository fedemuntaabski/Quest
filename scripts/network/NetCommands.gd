class_name CoopCommands
extends Node

## NetCommands (autoload, coop-12; class CoopCommands): the one road from player
## input to game state. Offline and on the host, request() validates and runs the
## command right here (same code path, no network); on a client it goes to the host
## as an RPC, the host validates it (hero ownership, existing block reasons) and
## runs the same existing API. A refusal comes back to the sender as floating text.
## Commands never trust args: every handler type-checks what it reads.

## A command was refused for the local player (UI feedback, tests).
signal refused(cmd: String, reason: String)

const INVALID := "Comando inválido"
const NOT_YOURS := "Ese héroe es de otro jugador"

## Commands that act on heroes the sender must own.
const OWNED_HERO_CMDS := ["move", "open_door", "ability", "consume", "equip", "unequip",
	"level_up", "choose_perk", "pickup_nexo", "altar"]

## sender peer -> [window_start_msec, count] (rate limit).
var _rate: Dictionary = {}


## Runs (or sends) a command; returns "" when it ran, else the refusal reason.
## On a client the answer is asynchronous: it returns "" once sent.
func request(cmd: String, args: Dictionary = {}) -> String:
	if Net.is_authority():
		var reason: String = await run_command(Net.local_peer(), cmd, args)
		if reason != "":
			_show_refusal(cmd, reason)
		return reason
	_rpc_request.rpc_id(1, cmd, args)
	return ""


@rpc("any_peer", "reliable")
func _rpc_request(cmd: String, args: Dictionary) -> void:
	if not Net.is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	var reason: String = await run_command(sender, cmd, args)
	if reason != "" and sender != 0:
		_rpc_refused.rpc_id(sender, cmd, reason)


@rpc("authority", "reliable")
func _rpc_refused(cmd: String, reason: String) -> void:
	_show_refusal(cmd, reason)


func _show_refusal(cmd: String, reason: String) -> void:
	refused.emit(cmd, reason)
	if reason == INVALID:
		return
	var text_mgr := ManagerLocator.get_floating_text_manager()
	var hero := ManagerLocator.get_player()
	if text_mgr and hero:
		text_mgr.spawn_text(hero.global_position + Vector2(0, -56), reason, QuestPalette.PARCHMENT)


## Host side: validates and executes. "" = done, else why not (nothing changed).
func run_command(sender: int, cmd: String, args: Dictionary) -> String:
	if not _rate_ok(sender):
		return "Demasiadas órdenes"
	if not has_method("_cmd_" + cmd):
		return INVALID
	if OWNED_HERO_CMDS.has(cmd):
		var ids := _hero_ids(args)
		if ids.is_empty():
			return INVALID
		var net := Net.session()
		for id in ids:
			if net and not net.owns(id, sender):
				return NOT_YOURS
	var reason: String = await call("_cmd_" + cmd, sender, args)
	QuestLogger.debug(QuestLogger.Category.NETWORK, "cmd %s from %d %s -> %s" % [cmd, sender, args, reason if reason != "" else "ok"])
	return reason


func _rate_ok(sender: int) -> bool:
	var net := Net.session()
	var limit: int = net.config.max_cmds_per_sec if net else 20
	var now := Time.get_ticks_msec()
	var r: Array = _rate.get(sender, [now, 0])
	if now - int(r[0]) >= 1000:
		r = [now, 0]
	r[1] = int(r[1]) + 1
	_rate[sender] = r
	return int(r[1]) <= limit


## Hero ids named by a command: args.hero (String) or args.heroes (Array of String).
func _hero_ids(args: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if args.get("hero") is String:
		out.append(args.hero)
	elif args.get("heroes") is Array:
		for id in args.heroes:
			if not (id is String):
				return []
			out.append(id)
	return out


# ─── lookups ──────────────────────────────────────────────────

func _hero(id: String) -> Player:
	for hero in ManagerLocator.get_heroes():
		if hero.stats.hero_id == id:
			return hero
	return null


func _heroes(args: Dictionary) -> Array[Player]:
	var out: Array[Player] = []
	for id in _hero_ids(args):
		var hero := _hero(id)
		if hero and hero.can_accept_input():
			out.append(hero)
	return out


func _zone(args: Dictionary) -> RoomZone:
	var rm := ManagerLocator.get_room_manager()
	if rm == null or not (args.get("zone") is String) or not rm.zones.has(args.zone):
		return null
	return rm.get_zone_node(args.zone)


func _slot(args: Dictionary) -> BuildingSlot:
	var zone := _zone(args)
	if zone == null or not (args.get("slot") is int):
		return null
	return zone.get_slot(args.slot)


func _pac() -> PlayerActionController:
	var main2d := ManagerLocator.get_main2d()
	return main2d.player_action_controller if main2d else null


static func _item(id: Variant) -> ItemData:
	return ItemCatalog.find(id) if id is String else null


# ─── handlers (host / offline only) ───────────────────────────

func _cmd_move(sender: int, args: Dictionary) -> String:
	var pac := _pac()
	var rm := ManagerLocator.get_room_manager()
	if pac == null or not (args.get("zone") is String) or not rm.zones.has(args.zone):
		return INVALID
	if not rm.is_zone_revealed(args.zone):
		return "Sala sin descubrir"
	if pac.is_peer_busy(sender):
		return "Ya hay una orden en curso"
	var heroes := _heroes(args)
	if heroes.is_empty():
		return "Ningún héroe puede moverse"
	await pac.move_heroes(heroes, args.zone, sender)
	return ""


func _cmd_open_door(sender: int, args: Dictionary) -> String:
	var pac := _pac()
	var door: Door = null
	if pac and args.get("door") is String:
		for d in pac.room_manager.get_all_doors():
			if d.door_id == args.door:
				door = d
	if door == null:
		return INVALID
	if pac.is_peer_busy(sender):
		return "Ya hay una orden en curso"
	var heroes := _heroes(args)
	var reason := pac.door_block_reason(door, heroes)
	if reason != "":
		return reason
	await pac.open_door(door, heroes, sender)
	return ""


func _cmd_toggle_power(_sender: int, args: Dictionary) -> String:
	var zone := _zone(args)
	if zone == null or zone.kind != "room":
		return INVALID
	if not ManagerLocator.get_room_manager().is_zone_revealed(zone.zone_id):
		return "Sala sin descubrir"
	if not zone.is_powered:
		var rm := ManagerLocator.get_resource_manager()
		if rm.get_resource("dust") < zone.next_power_cost():
			return "Polvo insuficiente"
	zone.toggle_power()
	return ""


func _cmd_build(_sender: int, args: Dictionary) -> String:
	var slot := _slot(args)
	if slot == null or not (args.get("type") is int) or not Module.CATALOG.has(args.type):
		return INVALID
	if not slot.is_empty():
		return "Slot ocupado"
	var type := args.type as Module.ModuleType
	var reason := BuildingMenu.build_block_reason(slot, type)
	if reason != "":
		return reason
	if not ManagerLocator.get_resource_manager().spend_resource(BuildingMenu.COST_RESOURCE, Module.get_cost(type)):
		return "Falta Industria"
	slot.build(type)
	QuestLogger.info(QuestLogger.Category.MODULE, "Built '%s' in zone '%s'." % [Module.CATALOG[type]["label"], slot.zone_id])
	return ""


func _built_module(args: Dictionary) -> Module:
	var slot := _slot(args)
	return slot.built_module as Module if slot and not slot.is_empty() else null


func _cmd_repair(_sender: int, args: Dictionary) -> String:
	var module := _built_module(args)
	if module == null:
		return INVALID
	if module.repair_cost() <= 0:
		return "No está dañado"
	return "" if module.repair() else "Falta Industria"


func _cmd_demolish(_sender: int, args: Dictionary) -> String:
	var module := _built_module(args)
	if module == null or not module.is_targetable():
		return INVALID
	module.demolish()
	return ""


func _cmd_research(_sender: int, args: Dictionary) -> String:
	if not (args.get("id") is String):
		return INVALID
	var rm := ManagerLocator.get_resource_manager()
	var reason := rm.get_research_block_reason(args.id)
	if reason != "":
		return reason
	return "" if rm.research(args.id) else "Falta Ciencia"


func _stats_target(args: Dictionary) -> String:
	if not (args.get("hero") is String):
		return ""
	var ps := ManagerLocator.get_player_stats()
	return args.hero if ps and ps.get_hero_stats(args.hero) != null else ""


func _cmd_level_up(_sender: int, args: Dictionary) -> String:
	var id := _stats_target(args)
	if id == "":
		return INVALID
	var ps := ManagerLocator.get_player_stats()
	var preview := ps.get_level_up_preview(id)
	if preview.get("maxed", false):
		return "Nivel máximo"
	return "" if ps.level_up_hero(id) else "Falta Comida"


func _cmd_heal(_sender: int, args: Dictionary) -> String:
	var id := _stats_target(args)
	if id == "":
		return INVALID
	var ps := ManagerLocator.get_player_stats()
	if ps.get_heal_cost(id) <= 0:
		return "Nada que curar"
	return "" if ps.heal_hero(id) else "Falta Comida"


func _cmd_revive(_sender: int, args: Dictionary) -> String:
	var id := _stats_target(args)
	if id == "":
		return INVALID
	var ps := ManagerLocator.get_player_stats()
	var reason := ps.get_revive_block_reason(id)
	if reason != "":
		return reason
	return "" if ps.revive_hero(id) else "Falta Comida"


func _cmd_choose_perk(_sender: int, args: Dictionary) -> String:
	var id := _stats_target(args)
	if id == "" or not (args.get("perk") is String or args.get("perk") is StringName):
		return INVALID
	return "" if ManagerLocator.get_player_stats().choose_perk(id, StringName(args.perk)) else "Mejora no disponible"


func _cmd_equip(_sender: int, args: Dictionary) -> String:
	var item := _item(args.get("item"))
	if item == null or _stats_target(args) == "":
		return INVALID
	var inv := ManagerLocator.get_party_inventory()
	var reason := inv.can_equip(args.hero, item)
	if reason != "":
		return reason
	return "" if inv.equip(args.hero, item) else "No se pudo equipar"


func _cmd_unequip(_sender: int, args: Dictionary) -> String:
	if _stats_target(args) == "" or not (args.get("slot") is int) or not (args.get("index", 0) is int):
		return INVALID
	if not ItemData.Slot.values().has(args.slot):
		return INVALID
	var inv := ManagerLocator.get_party_inventory()
	var slot := args.slot as ItemData.Slot
	var reason := inv.can_unequip(args.hero, slot, args.get("index", 0))
	if reason != "":
		return reason
	return "" if inv.unequip(args.hero, slot, args.get("index", 0)) else "No se pudo quitar"


func _cmd_consume(_sender: int, args: Dictionary) -> String:
	var hero := _hero(str(args.get("hero", "")))
	if hero == null or not (args.get("index") is int) or hero.inventory == null:
		return INVALID
	var reason := hero.inventory.get_block_reason(args.index)
	if reason != "":
		return reason
	return "" if hero.inventory.use(args.index) else "No se pudo usar"


func _cmd_ability(_sender: int, args: Dictionary) -> String:
	var hero := _hero(str(args.get("hero", "")))
	if hero == null or hero.abilities == null:
		return INVALID
	var reason := hero.abilities.get_block_reason()
	if reason != "":
		return reason
	return "" if hero.abilities.try_activate() else "No se pudo usar"


func _cmd_pickup_nexo(_sender: int, args: Dictionary) -> String:
	var hero := _hero(str(args.get("hero", "")))
	var main2d := ManagerLocator.get_main2d()
	if hero == null or main2d == null:
		return INVALID
	var ctrl: NexoController = main2d.nexo_controller
	var reason := ctrl.get_block_reason(hero)
	if reason != "":
		return reason
	ctrl.confirm_pickup(hero)
	return ""


func _cmd_recruit(sender: int, args: Dictionary) -> String:
	var main2d := ManagerLocator.get_main2d()
	if main2d == null or not (args.get("zone") is String) or not (args.get("resource") is String):
		return INVALID
	var cage: PrisonerCage = main2d.prisoner_spawner.cages.get(args.zone)
	if cage == null or not is_instance_valid(cage):
		return INVALID
	var reason := cage.get_block_reason()
	if reason != "":
		return reason
	if not cage.free_with(args.resource):
		return "Falta %s" % PrisonerCage.RESOURCE_NAMES.get(args.resource, args.resource)
	var net := Net.session()
	if net and net.is_online():
		net.assign_hero(cage.hero_id, sender)  # a freed hero belongs to whoever paid
	return ""


func _cmd_altar(_sender: int, args: Dictionary) -> String:
	var main2d := ManagerLocator.get_main2d()
	if main2d == null or not (args.get("zone") is String):
		return INVALID
	var altar: AltarShrine = main2d.altars.get(args.zone)
	if altar == null:
		return INVALID
	var reason := altar.get_block_reason(args.hero)
	if reason != "":
		return reason
	return "" if altar.sacrifice(args.hero) != null else "Mochila llena"


func _cmd_open_chest(_sender: int, args: Dictionary) -> String:
	var main2d := ManagerLocator.get_main2d()
	if main2d == null or not (args.get("zone") is String):
		return INVALID
	var chest: Chest = main2d.loot_spawner.chests.get(args.zone)
	if chest == null or not chest.is_closed():
		return INVALID
	var inside := false
	for hero in ManagerLocator.get_heroes():
		inside = inside or (hero.stats.is_alive() and hero.current_zone_id == args.zone)
	if not inside:
		return "Un héroe tiene que estar en la sala"
	return "" if chest.try_open() else "Mochila llena"
