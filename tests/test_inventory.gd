extends SceneTree

## Session impl-6, fase 2A: PartyInventory + equipment layer + consumables + chests.
##   - stash (20), stacks, equip/unequip/swap, slot capacities, allowed_heroes
##   - equipment changes the exact stats; levels and perks keep it; it survives
##     a new floor (clear_party + register) and is reset per run
##   - consumables: heal, timed buffs on their own multiplier source, cooldown,
##     blocked in tactical pause and at full HP
##   - chests: open when a hero enters, rarity shown, full stash leaves them
##     closed, deterministic per seed, loot_chance per room type, floor-end reward
##   godot --headless --path . --script res://tests/test_inventory.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"

var failures: Array[String] = []
var ps: Node
var inv: Node
var resources: Node


func _initialize() -> void:
	ps = root.get_node("PlayerStats")
	inv = root.get_node("PartyInventory")
	resources = root.get_node("ResourceManager")
	await process_frame  # autoload _ready (PlayerStats connects to PartyInventory) has not run yet at _initialize
	_reset()
	_test_stash_and_equip()
	_test_stats_layer()
	await _test_consumables()
	await _test_chests()
	_test_loot_config()
	_reset()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_inventory: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _ids(items: Array) -> Array[String]:
	var out: Array[String] = []
	for item: ItemData in items:
		out.append(item.id)
	return out


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _reset() -> void:
	inv.reset()
	ps.reset_run_upgrades()
	ps.clear_party()
	resources.reset_resources(15, 999, 10, 20)
	resources.reset_research()


func _item(id: String) -> ItemData:
	return load("res://resources/items/%s.tres" % id) as ItemData


func _bare(id: String) -> CharacterStats:
	var data := CharacterDatabase.get_by_id(id)
	var s := CharacterStats.new()
	root.add_child(s)
	s.hero_id = id
	s.base_hp = data.base_hp
	s.set_base_attack(data.attack_damage, data.attack_interval)
	s.set_base_attack_range(data.attack_range)
	ps.register(s)
	return s


func _test_stash_and_equip() -> void:
	var sword := _item("sword_iron")
	var potion := _item("potion_health")
	var robe := _item("armor_robe")
	_expect(inv.stash_size() == 0 and inv.STASH_CAPACITY == 20, "empty stash of 20")
	var acquired: Array = []
	inv.item_acquired.connect(func(item: ItemData) -> void: acquired.append(item.id))
	_expect(inv.add_item(sword) and inv.add_item(potion) and inv.add_item(potion), "adding items")
	_expect(inv.stash_size() == 2 and inv.count_of(potion) == 2, "potions stack: %d stacks, %d potions" % [inv.stash_size(), inv.count_of(potion)])
	_expect(acquired == ["sword_iron", "potion_health", "potion_health"], "item_acquired signals %s" % [acquired])

	_expect(inv.can_equip("warrior", sword) == "", "warrior can equip the sword")
	_expect(inv.can_equip("warrior", robe) != "", "a robe is not in the stash")
	inv.add_item(robe)
	_expect(inv.can_equip("warrior", robe) != "" and inv.can_equip("mage", robe) == "", "armor_robe is for mage/rogue only")
	_expect(not inv.equip("warrior", robe), "equip refused by allowed_heroes")

	_expect(inv.equip("warrior", sword) and inv.count_of(sword) == 0, "equip moves the item out of the stash")
	_expect(_ids(inv.get_equipped("warrior", ItemData.Slot.WEAPON)) == ["sword_iron"], "weapon equipped")
	var second := _item("sword_steel")
	inv.add_item(second)
	_expect(inv.equip("warrior", second) and _ids(inv.get_equipped("warrior", ItemData.Slot.WEAPON)) == ["sword_steel"], "equipping a second weapon swaps")
	_expect(inv.count_of(sword) == 1, "the swapped-out weapon returns to the stash")
	_expect(inv.can_unequip("warrior", ItemData.Slot.WEAPON) == "" and inv.unequip("warrior", ItemData.Slot.WEAPON) and inv.count_of(second) == 1, "unequip back to the stash")

	# Two consumables per hero, a third is refused.
	_expect(inv.equip("warrior", potion) and inv.equip("warrior", potion), "two consumables")
	_expect(inv.can_equip("warrior", potion) != "" or inv.count_of(potion) == 0, "no stack left to equip")
	var clarity := _item("potion_clarity")
	inv.add_item(clarity)
	_expect(inv.can_equip("warrior", clarity).begins_with("Sin espacio"), "third consumable refused: '%s'" % inv.can_equip("warrior", clarity))
	_expect(inv.get_equipped("warrior", ItemData.Slot.CONSUMABLE).size() == 2, "2 consumables equipped")

	# Stash capacity: 20 stacks, then add fails; unequip into a full stash is refused.
	_reset()
	var swords: Array[String] = ["sword_bronze", "sword_iron", "sword_steel", "sword_ember", "sword_jade", "sword_gold", "armor_leather", "armor_robe", "armor_iron", "armor_copper", "armor_steel", "armor_gold", "armor_jade", "book_embers", "book_tides"]
	for id in swords:
		_expect(inv.add_item(_item(id)), "add %s" % id)
	for i in 5:
		inv.stash.append(ItemStack.new(_item("sword_bronze"), 1))
	_expect(inv.stash_size() == 20 and not inv.can_add(_item("sword_gold")), "stash full at 20 stacks")
	_expect(not inv.add_item(_item("sword_gold")) and inv.stash_size() == 20, "add refused when full")
	_expect(inv.can_add(_item("potion_health")) == false, "no room even for a new stack")
	_reset()
	inv.add_item(sword)
	inv.equip("warrior", sword)
	for i in 20:
		inv.stash.append(ItemStack.new(_item("sword_bronze"), 1))
	_expect(inv.can_unequip("warrior", ItemData.Slot.WEAPON) == "Mochila llena" and not inv.unequip("warrior", ItemData.Slot.WEAPON), "unequip into a full stash is refused")
	_reset()


func _test_stats_layer() -> void:
	var s := _bare("warrior")
	var base_damage := s.attack_damage
	var base_interval := s.attack_interval
	var base_range := s.attack_range
	var base_hp := s.max_hp
	var cfg: UpgradeConfig = ps.run_upgrade_config
	var ember := _item("sword_ember")      # +3 damage, -0.1 interval
	var armor := _item("armor_steel")      # +20 hp
	inv.add_item(ember)
	inv.add_item(armor)
	inv.equip("warrior", ember)
	_expect(s.attack_damage == base_damage + 3 and _near(s.attack_interval, maxf(cfg.min_attack_interval, base_interval - 0.1)), "sword: damage %d interval %f" % [s.attack_damage, s.attack_interval])
	var hp_before := s.current_hp
	inv.equip("warrior", armor)
	_expect(s.max_hp == base_hp + 20 and s.current_hp == hp_before + 20, "armor: %d/%d" % [s.current_hp, s.max_hp])
	_expect(ps.get_bonus("warrior")["hp"] == 20 and ps.get_bonus("warrior")["attack_damage"] == 3, "get_bonus reports the layer")

	# Levels keep the equipment (third layer).
	resources.add_resource("food", 999)
	_expect(ps.level_up_hero("warrior"), "level up")
	_expect(s.attack_damage == cfg.damage_at(s.base_attack_damage, 1) + 3, "level-up overwrote the sword bonus (%d)" % s.attack_damage)
	_expect(s.max_hp == base_hp + cfg.hp_per_level + 20, "level-up lost the armor HP (%d)" % s.max_hp)

	# Unequip shrinks HP but never kills.
	s.current_hp = 5
	inv.unequip("warrior", ItemData.Slot.ARMOR)
	_expect(s.max_hp == base_hp + cfg.hp_per_level and s.current_hp == 1 and s.is_alive(), "unequip: %d/%d must leave 1 HP, not kill" % [s.current_hp, s.max_hp])

	# New floor: the party is rebuilt and registers again, equipment comes back.
	ps.clear_party()
	var fresh := _bare("warrior")
	_expect(fresh.attack_damage == cfg.damage_at(fresh.base_attack_damage, 1) + 3, "equipment lost on a new floor (damage %d)" % fresh.attack_damage)
	# Cap: 120.
	var tank := _bare("tank")
	var jade := _item("armor_jade")
	inv.add_item(jade)
	inv.equip("tank", jade)
	_expect(tank.max_hp == tank.base_hp + 30 and tank.max_hp <= StatBalance.PLAYER_MAX_HP and StatBalance.PLAYER_MAX_HP == 120, "tank + jade: %d (cap %d)" % [tank.max_hp, StatBalance.PLAYER_MAX_HP])

	# New run: stash, loadouts and bonus are gone.
	inv.reset()
	ps.reset_run_upgrades()
	ps.refresh_stats()
	_expect(inv.stash_size() == 0 and inv.get_equipped("warrior", ItemData.Slot.WEAPON).is_empty(), "reset empties stash and loadouts")
	_expect(fresh.attack_damage == fresh.base_attack_damage and fresh.max_hp == fresh.base_hp and tank.max_hp == tank.base_hp, "reset: stats back to base")
	for node in [s, fresh, tank]:
		node.queue_free()
	_reset()


func _boot(ids: Array[String]) -> Node:
	_reset()
	root.get_node("GameSession").set_selection(ids)
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	return main2d


func _free(main2d: Node) -> void:
	paused = false
	Engine.time_scale = 1.0
	main2d.queue_free()
	await process_frame
	await process_frame


func _hero(main2d: Node, id: String) -> Player:
	for hero: Player in main2d.heroes:
		if hero.stats.hero_id == id:
			return hero
	failures.append("hero %s not spawned" % id)
	return null


func _test_consumables() -> void:
	var main2d := await _boot(["warrior", "tank"] as Array[String])
	var warrior := _hero(main2d, "warrior")
	var health := _item("potion_health")
	var fury := _item("potion_fury")
	var clarity := _item("potion_clarity")
	for item in [health, health, fury, clarity]:
		inv.add_item(item)
	inv.equip("warrior", health)
	inv.equip("warrior", fury)
	_expect(warrior.inventory != null, "Player has an InventoryComponent")

	# Full HP: heal refused, nothing spent.
	_expect(warrior.inventory.get_block_reason(0) == "Vida completa" and not warrior.inventory.use(0), "heal at full HP is refused")
	_expect(inv.get_equipped("warrior", ItemData.Slot.CONSUMABLE).size() == 2, "nothing spent when refused")
	warrior.stats.current_hp = 3
	_expect(warrior.inventory.use(0) and warrior.stats.current_hp == 13, "potion heals 10 (got %d)" % warrior.stats.current_hp)
	_expect(inv.get_equipped("warrior", ItemData.Slot.CONSUMABLE).size() == 1 and inv.count_of(health) == 0 or inv.count_of(health) == 1, "the used potion leaves the slot")

	# Cooldown applies to the same item; tactical pause blocks; fury buff on its own source.
	inv.equip("warrior", health)
	warrior.stats.current_hp = 3
	var health_slot: int = inv.get_equipped("warrior", ItemData.Slot.CONSUMABLE).find(health)
	_expect(warrior.inventory.get_block_reason(health_slot).begins_with("En enfriamiento"), "same potion on cooldown: '%s'" % warrior.inventory.get_block_reason(health_slot))
	var fury_slot: int = inv.get_equipped("warrior", ItemData.Slot.CONSUMABLE).find(fury)
	Engine.time_scale = 0.0
	_expect(warrior.inventory.get_block_reason(fury_slot).begins_with("No se puede usar en pausa"), "blocked in tactical pause: '%s'" % warrior.inventory.get_block_reason(fury_slot))
	Engine.time_scale = 1.0
	warrior.stats.set_attack_mult(1.5)  # a hero ability buff running
	var damage_before: int = warrior.hitbox.damage
	_expect(warrior.inventory.use(fury_slot), "fury used")
	_expect(_near(warrior.stats.attack_mult, 1.5 * 1.5) and warrior.hitbox.damage >= damage_before, "fury multiplies on its own source (x%f)" % warrior.stats.attack_mult)
	warrior.stats.set_attack_mult(1.0)  # the ability ends first: the potion must stay
	_expect(_near(warrior.stats.attack_mult, 1.5), "ending the ability buff keeps the potion buff (x%f)" % warrior.stats.attack_mult)
	warrior.stats.set_attack_mult_source(&"potion", 1.0)
	_expect(_near(warrior.stats.attack_mult, 1.0), "potion source cleared")

	# Speed potion shortens the effective interval, not the base one.
	var interval := warrior.stats.attack_interval
	warrior.stats.set_interval_mult_source(&"potion", 0.7)
	_expect(_near(warrior.stats.effective_attack_interval(), interval * 0.7) and _near(warrior.stats.attack_interval, interval), "speed buff acts on the effective interval")
	warrior.stats.set_interval_mult_source(&"potion", 1.0)
	_expect(_near(warrior.stats.effective_attack_interval(), interval), "speed buff cleared")
	await _free(main2d)


func _test_chests() -> void:
	var main2d := await _boot(["warrior", "tank"] as Array[String])
	var rm: RoomManager = main2d.room_manager
	var loot: LootSpawner = main2d.loot_spawner
	var zone := ""
	for zone_id in rm.get_zone_ids():
		if rm.get_zone_kind(zone_id) == "room" and zone_id != rm.get_start_zone_id():
			zone = zone_id
			break
	var rare := _item("sword_jade")
	var chest := loot.spawn_chest(zone, rare)
	await process_frame
	_expect(chest.is_closed() and chest._sprite.texture != null, "a chest starts closed with a sprite")
	var closed_texture := chest._sprite.texture
	var hero: Player = main2d.heroes[0]
	hero.set_zone(zone, rm.get_center(zone), main2d.floor_layer)
	_expect(not chest.is_closed() and inv.count_of(rare) == 1, "a hero entering opens the chest and the item reaches the stash")
	_expect(chest._sprite.texture != closed_texture and chest._item_icon != null and chest._item_icon.texture == rare.icon, "open sprite and the item icon over it")

	# Full stash: it stays closed, and opens later when there is room.
	var other := loot.spawn_chest(rm.get_start_zone_id(), _item("armor_jade"))
	for i in 19:
		inv.stash.append(ItemStack.new(_item("sword_bronze"), 1))
	_expect(inv.stash_size() == 20, "stash filled (%d)" % inv.stash_size())
	main2d.heroes[1].set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	_expect(other.is_closed() and inv.count_of(_item("armor_jade")) == 0, "full stash leaves the chest closed")
	inv.stash.pop_back()
	main2d.heroes[1].set_zone(rm.get_start_zone_id(), rm.get_center(rm.get_start_zone_id()), main2d.floor_layer)
	_expect(not other.is_closed() and inv.count_of(_item("armor_jade")) == 1, "re-entering with room opens it")

	# Floor-end reward goes straight to the stash.
	inv.reset()
	var floor_manager: FloorManager = main2d.floor_manager
	floor_manager.config = floor_manager.config.duplicate()
	floor_manager.config.floor_end_loot_chance = 1.0
	floor_manager.complete_floor()
	_expect(inv.stash_size() == 1, "floor completion grants an item (stash %d)" % inv.stash_size())
	await _free(main2d)


func _test_loot_config() -> void:
	var config := FloorManager.DEFAULT_CONFIG
	_expect(_near(config.loot_chance(RoomData.RoomType.LOOT), 1.0), "Loot rooms always hold a chest")
	_expect(config.loot_chance(RoomData.RoomType.ELITE) > config.loot_chance(RoomData.RoomType.REST), "Elite rooms hold one more often than Rest")
	_expect(config.loot_chance(RoomData.RoomType.COMBAT) > 0.0 and config.loot_chance(RoomData.RoomType.COMBAT) < 0.2, "Combat rooms: low chance (%f)" % config.loot_chance(RoomData.RoomType.COMBAT))
	_expect(config.loot_chance(RoomData.RoomType.START) == 0.0 and config.loot_chance(RoomData.RoomType.EXIT) == 0.0, "no chests in Start/Exit")
	# Same seed -> same floor loot.
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = hash([123, "room_3", "chest"])
	b.seed = hash([123, "room_3", "chest"])
	_expect(a.randf() == b.randf() and LootSpawner.roll_item(a).id == LootSpawner.roll_item(b).id, "chest roll is deterministic per seed")
