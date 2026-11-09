extends SceneTree

## juego-22: every equippable item and every class perk through PlayerStats.get_stat_breakdown:
##   - equipping puts exactly its modifiers in the "equipment" column and the total follows;
##     unequipping takes them out (back to the numbers before)
##   - a weapon + an armor + a talisman stack (column = the sum)
##   - every perk puts exactly its stat mods in the "perks" column; a new run clears it
##   - no item without an effect (modifiers or a consumable effect)
## Prints a power table (dps gain + effective-HP gain vs the hero's level-0 numbers, averaged
## over the heroes that may carry it) and marks items > DOMINANT_PCT over the mean of their
## rarity and slot (a weapon and an armor are worn together: they don't compete).
## juego-23 (owner's picks, docs/BALANCE.md): no uncommon weapon dominates another (sword_steel
## went Rare), the Rare talisman reaches 70 % of the Uncommon one (was 30 %) (book_tides -0.3 s) and the
## Epic armor_steel beats the Rare armor_copper (23 HP).
##   godot --headless --path . --script res://tests/test_equipo_efectos.gd

const HEROES: Array[String] = ["warrior", "mage", "rogue", "tank"]
const KEYS: Array[String] = ["hp", "attack_damage", "attack_interval", "attack_range"]
## Range is worth half: it only shortens the walk-in of a fight.
const RANGE_WEIGHT := 0.5
const DOMINANT_PCT := 15.0

var failures: Array[String] = []
var ps: Node
var inv: Node


func _initialize() -> void:
	await process_frame  # autoload _ready (PlayerStats listens to PartyInventory there)
	ps = root.get_node("PlayerStats")
	inv = root.get_node("PartyInventory")
	var stats := {}
	for id in HEROES:
		stats[id] = _bare(id)
	var catalog := ItemCatalog.get_default()
	var power_rows: Array[Dictionary] = []
	for item in catalog.items:
		if item.is_consumable():
			_expect(int(item.consumable_effect) != 0 or item.effect_value != 0.0, "%s: consumable without an effect" % item.id)
			continue
		_expect(not item.modifiers.is_empty(), "%s: equippable without modifiers" % item.id)
		var powers: Array[float] = []
		for id in HEROES:
			if not item.allowed_heroes.is_empty() and not item.allowed_heroes.has(id):
				continue
			powers.append(_check_item(id, item))
		_expect(not powers.is_empty(), "%s: no hero may carry it" % item.id)
		var mean := 0.0
		for p in powers:
			mean += p
		power_rows.append({"id": item.id, "rarity": item.rarity, "slot": item.slot, "power": mean / maxf(powers.size(), 1)})
	_check_stack(catalog)
	_check_perks(stats)
	_report(power_rows)
	_check_rarity_picks(power_rows)
	for id in HEROES:
		stats[id].queue_free()
	ps.clear_party()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_equipo_efectos: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)


## CharacterStats set up like Player._ready does it (no scene), registered in PlayerStats.
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


func _rows(id: String) -> Dictionary:
	var out := {}
	for row in ps.get_stat_breakdown(id):
		out[row["key"]] = row
	return out


## Equip, compare the breakdown, unequip; returns the item's power for this hero.
func _check_item(id: String, item: ItemData) -> float:
	var before := _rows(id)
	inv.add_item(item)
	_expect(inv.equip(id, item), "%s: %s could not equip it (%s)" % [item.id, id, inv.can_equip(id, item)])
	var after := _rows(id)
	for key in KEYS:
		var want := float(item.modifiers.get(key, 0))
		var got := float(after[key]["equipment"]) - float(before[key]["equipment"])
		_expect(is_equal_approx(got, want), "%s on %s: %s equipment +%s, want +%s" % [item.id, id, key, got, want])
		var total_want := float(before[key]["total"]) + want
		if key == "hp":
			total_want = minf(total_want, StatBalance.PLAYER_MAX_HP)
		elif key == "attack_interval":
			total_want = maxf(total_want, 0.0)
		_expect(absf(float(after[key]["total"]) - total_want) < 0.051, "%s on %s: %s total %s, want %s" % [item.id, id, key, after[key]["total"], total_want])
	var power := _power(before, after, id)
	_expect(inv.unequip(id, item.slot, inv.get_equipped(id, item.slot).find(item)), "%s: %s could not unequip it" % [item.id, id])
	var back := _rows(id)
	for key in KEYS:
		_expect(is_equal_approx(float(back[key]["total"]), float(before[key]["total"])) and is_equal_approx(float(back[key]["equipment"]), float(before[key]["equipment"])),
			"%s off %s: %s total %s, before %s" % [item.id, id, key, back[key]["total"], before[key]["total"]])
	inv.reset()
	return power


## Relative gain: DPS + effective HP (+ half the range gain).
func _power(before: Dictionary, after: Dictionary, id: String) -> float:
	var data := CharacterDatabase.get_by_id(id)
	var reduction := BalanceSim.damage_reduction_pct(data)
	var dps0 := float(before["attack_damage"]["total"]) / maxf(float(before["attack_interval"]["total"]), 0.05)
	var dps1 := float(after["attack_damage"]["total"]) / maxf(float(after["attack_interval"]["total"]), 0.05)
	var ehp0 := float(before["hp"]["total"]) / (1.0 - reduction)
	var ehp1 := float(after["hp"]["total"]) / (1.0 - reduction)
	var range_gain := float(after["attack_range"]["total"]) / maxf(float(before["attack_range"]["total"]), 1.0) - 1.0
	return (dps1 / dps0 - 1.0) + (ehp1 / ehp0 - 1.0) + RANGE_WEIGHT * range_gain


## Weapon + armor + talisman on one hero: the equipment column is the sum.
func _check_stack(catalog: ItemCatalog) -> void:
	var id := "mage"
	var picked: Array[ItemData] = []
	for slot in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.TALISMAN]:
		for item in catalog.items:
			if item.slot == slot and (item.allowed_heroes.is_empty() or item.allowed_heroes.has(id)) and not item.modifiers.is_empty():
				picked.append(item)
				break
	_expect(picked.size() == 3, "stack: found %d of 3 slots for the mage" % picked.size())
	var before := _rows(id)
	for item in picked:
		inv.add_item(item)
		inv.equip(id, item)
	var after := _rows(id)
	for key in KEYS:
		var want := 0.0
		for item in picked:
			want += float(item.modifiers.get(key, 0))
		_expect(is_equal_approx(float(after[key]["equipment"]) - float(before[key]["equipment"]), want), "stack: %s equipment %s, want %s" % [key, after[key]["equipment"], want])
	inv.reset()
	ps.refresh_stats()
	var back := _rows(id)
	_expect(KEYS.all(func(k: String) -> bool: return is_equal_approx(float(back[k]["total"]), float(before[k]["total"]))), "stack: totals did not come back after clearing the loadout")


func _check_perks(stats: Dictionary) -> void:
	for id in HEROES:
		var data := CharacterDatabase.get_by_id(id)
		for perk in data.perks:
			ps.reset_run_upgrades()
			ps.refresh_stats()
			(root.get_node("ResourceManager") as ResourceManager).reset_resources(15, 9999, 10, 20)
			while int(ps.run_levels.get(id, 0)) < perk.unlock_level:
				if not ps.level_up_hero(id):
					break
			# A level-5 perk is offered once the level-3 choice is made: take another group's first.
			while not ps.get_pending_perk_choices(id).has(perk) and not ps.get_pending_perk_choices(id).is_empty():
				var other: HeroPerk = ps.get_pending_perk_choices(id)[0]
				if not ps.choose_perk(id, other.id):
					break
			var before := _rows(id)
			_expect(ps.choose_perk(id, perk.id), "%s: perk %s refused at level %d" % [id, perk.id, int(ps.run_levels.get(id, 0))])
			var after := _rows(id)
			for key in KEYS:
				var want := float(perk.mods.get(key, 0))
				_expect(is_equal_approx(float(after[key]["perks"]) - float(before[key]["perks"]), want), "%s/%s: %s perks %s, want +%s" % [id, perk.id, key, after[key]["perks"], want])
			_expect(perk.mods.keys().any(func(k: String) -> bool: return HeroPerk.MOD_LABELS.has(k)), "%s/%s: perk without a known mod" % [id, perk.id])
			ps.reset_run_upgrades()
			ps.refresh_stats()
			var reset := _rows(id)
			_expect(KEYS.all(func(k: String) -> bool: return is_equal_approx(float(reset[k]["perks"]), 0.0)), "%s/%s: perks column not cleared by a new run" % [id, perk.id])


func _report(rows: Array[Dictionary]) -> void:
	var groups := {}
	for row in rows:
		var key := "%d|%d" % [row["rarity"], row["slot"]]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(row)
	print("item power (dps + ehp gain vs level 0, x%.1f range):" % RANGE_WEIGHT)
	for key in groups.keys():
		var list: Array = groups[key]
		var rarity: int = list[0]["rarity"]
		var mean := 0.0
		for row in list:
			mean += row["power"]
		mean /= list.size()
		for row in list:
			var over: float = (row["power"] / maxf(mean, 0.0001) - 1.0) * 100.0
			print("  %-14s %-9s slot %d power %5.1f %%  vs rarity+slot mean %+5.0f %%%s" % [row["id"], ItemData.Rarity.keys()[rarity], row["slot"], row["power"] * 100.0, over, "  <- DOMINANT" if over > DOMINANT_PCT and list.size() > 1 else ""])


func _check_rarity_picks(rows: Array[Dictionary]) -> void:
	var power := {}
	var weapons_by_rarity := {}
	for row in rows:
		power[row["id"]] = float(row["power"])
		if int(row["slot"]) == ItemData.Slot.WEAPON:
			weapons_by_rarity[row["rarity"]] = int(weapons_by_rarity.get(row["rarity"], 0)) + 1
	_expect(int(weapons_by_rarity.get(ItemData.Rarity.UNCOMMON, 0)) == 1, "uncommon weapons: %d (sword_steel dominated sword_iron)" % int(weapons_by_rarity.get(ItemData.Rarity.UNCOMMON, 0)))
	_expect(float(power["book_tides"]) >= 0.7 * float(power["book_embers"]), "book_tides %.0f %% vs book_embers %.0f %%" % [power["book_tides"] * 100.0, power["book_embers"] * 100.0])
	_expect(float(power["armor_steel"]) > 1.1 * float(power["armor_copper"]), "armor_steel %.0f %% vs armor_copper %.0f %%" % [power["armor_steel"] * 100.0, power["armor_copper"] * 100.0])
