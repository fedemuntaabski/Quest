extends Node

## PartyInventory — Autoload. The party's items for the current run: a shared
## stash (20 stacks) and, per hero, what is equipped (weapon 1, armor 1, relic 1,
## consumables 2). Run state: Main._begin_new_run() calls reset(); it survives
## floors (heroes are rebuilt every floor, PlayerStats re-reads the equipment bonus
## when each one registers). Data only: stats go through PlayerStats (third layer),
## consumable effects through InventoryComponent. Listed before PlayerStats in
## project.godot so PlayerStats can connect to it in its own _ready.
## Autoload code in --script runs without autoload identifiers: ManagerLocator only.

signal stash_changed
## `slot`/`item` of the change; item is null when it was an unequip.
signal equipment_changed(hero_id: String, slot: ItemData.Slot, item: ItemData)
signal item_acquired(item: ItemData)
signal item_used(hero_id: String, item: ItemData)

const STASH_CAPACITY := 20
const SLOT_CAPACITY := {
	ItemData.Slot.WEAPON: 1,
	ItemData.Slot.ARMOR: 1,
	ItemData.Slot.RELIC: 1,
	ItemData.Slot.CONSUMABLE: 2,
}

var stash: Array[ItemStack] = []
## hero_id -> {slot (int) -> Array[ItemData]}
var loadouts: Dictionary = {}


# ---------------- stash ----------------

## Adds to the stash (merging stackables). false when there is no room.
func add_item(item: ItemData) -> bool:
	if item == null or not can_add(item):
		return false
	var stack := _stack_with_room(item)
	if stack:
		stack.count += 1
	else:
		stash.append(ItemStack.new(item, 1))
	item_acquired.emit(item)
	stash_changed.emit()
	return true


func can_add(item: ItemData) -> bool:
	return item != null and (_stack_with_room(item) != null or stash.size() < STASH_CAPACITY)


func stash_size() -> int:
	return stash.size()


func count_of(item: ItemData) -> int:
	var total := 0
	for stack in stash:
		if stack.item == item:
			total += stack.count
	return total


## Every stashed copy as a flat list (the old "found items" view).
func stash_items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for stack in stash:
		for i in stack.count:
			out.append(stack.item)
	return out


func _stack_with_room(item: ItemData) -> ItemStack:
	if not item.stackable:
		return null
	for stack in stash:
		if stack.item == item and stack.count < maxi(item.max_stack, 1):
			return stack
	return null


func _remove_from_stash(item: ItemData) -> bool:
	for i in stash.size():
		if stash[i].item == item:
			stash[i].count -= 1
			if stash[i].count <= 0:
				stash.remove_at(i)
			return true
	return false


# ---------------- equipment ----------------

func get_equipped(hero_id: String, slot: ItemData.Slot) -> Array[ItemData]:
	var out: Array[ItemData] = []
	var by_slot: Dictionary = loadouts.get(hero_id, {})
	for item: ItemData in by_slot.get(int(slot), []):
		out.append(item)
	return out


## "" if `hero_id` can equip `item` (from the stash) now, else why not.
func can_equip(hero_id: String, item: ItemData) -> String:
	if item == null or count_of(item) == 0:
		return "No está en la mochila"
	if not item.allowed_heroes.is_empty() and not item.allowed_heroes.has(hero_id):
		return "No lo puede llevar este héroe"
	var slot_items := get_equipped(hero_id, item.slot)
	if slot_items.size() >= int(SLOT_CAPACITY[item.slot]) and item.slot == ItemData.Slot.CONSUMABLE:
		return "Sin espacio: ya lleva %d consumibles" % int(SLOT_CAPACITY[item.slot])
	return ""


## Equips a stashed item. A full single-item slot (weapon/armor/relic) swaps: the
## old one returns to the stash (always fits, the new one just left it).
func equip(hero_id: String, item: ItemData) -> bool:
	if can_equip(hero_id, item) != "":
		return false
	var by_slot: Dictionary = loadouts.get(hero_id, {})
	var list: Array = by_slot.get(int(item.slot), [])
	_remove_from_stash(item)
	if list.size() >= int(SLOT_CAPACITY[item.slot]):
		var old: ItemData = list.pop_front()
		_add_without_event(old)
	list.append(item)
	by_slot[int(item.slot)] = list
	loadouts[hero_id] = by_slot
	stash_changed.emit()
	equipment_changed.emit(hero_id, item.slot, item)
	return true


## "" if the equipped item at `index` can go back to the stash.
func can_unequip(hero_id: String, slot: ItemData.Slot, index: int = 0) -> String:
	var list := get_equipped(hero_id, slot)
	if index < 0 or index >= list.size():
		return "No hay nada equipado"
	if not can_add(list[index]):
		return "Mochila llena"
	return ""


func unequip(hero_id: String, slot: ItemData.Slot, index: int = 0) -> bool:
	if can_unequip(hero_id, slot, index) != "":
		return false
	var list: Array = loadouts[hero_id][int(slot)]
	var item: ItemData = list.pop_at(index)
	_add_without_event(item)
	stash_changed.emit()
	equipment_changed.emit(hero_id, slot, null)
	return true


## Removes the consumable at `index` of the hero's consumable slots (it was used).
## Returns it, null if there is none. Does not emit equipment_changed: consumables carry no stats.
func consume(hero_id: String, index: int) -> ItemData:
	var list := get_equipped(hero_id, ItemData.Slot.CONSUMABLE)
	if index < 0 or index >= list.size():
		return null
	var item: ItemData = list[index]
	(loadouts[hero_id][int(ItemData.Slot.CONSUMABLE)] as Array).remove_at(index)
	item_used.emit(hero_id, item)
	equipment_changed.emit(hero_id, ItemData.Slot.CONSUMABLE, null)
	return item


## Sum of the `modifiers` of the hero's equipped weapon/armor/relic
## (keys: hp, attack_damage, attack_interval, attack_range).
func get_equipment_bonus(hero_id: String) -> Dictionary:
	var bonus := {"hp": 0, "attack_damage": 0, "attack_interval": 0.0, "attack_range": 0.0}
	for slot in [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.RELIC]:
		for item in get_equipped(hero_id, slot):
			bonus["hp"] += int(item.modifiers.get("hp", 0))
			bonus["attack_damage"] += int(item.modifiers.get("attack_damage", 0))
			bonus["attack_interval"] += float(item.modifiers.get("attack_interval", 0.0))
			bonus["attack_range"] += float(item.modifiers.get("attack_range", 0.0))
	return bonus


## New run (Main._begin_new_run).
func reset() -> void:
	var heroes := loadouts.keys()
	stash.clear()
	loadouts.clear()
	stash_changed.emit()
	for hero_id: String in heroes:
		equipment_changed.emit(hero_id, ItemData.Slot.WEAPON, null)


func _add_without_event(item: ItemData) -> void:
	var stack := _stack_with_room(item)
	if stack:
		stack.count += 1
	else:
		stash.append(ItemStack.new(item, 1))
