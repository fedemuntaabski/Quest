class_name LootSpawner
extends Node2D

## LootSpawner: when a room is discovered it may hold a Chest. The chance is the
## room type's RoomTypeRule.loot_chance (Loot rooms 100 %, Elite high, others low;
## FloorConfig.default_loot_chance for rooms without a rule); item and roll are
## seeded with (floor seed, room) so a floor always holds the same loot. A chest
## opens when a hero enters its room (Player.zone_changed) and goes to the party
## stash (Chest).

const CHEST_OFFSET := Vector2(0, -56)
const NO_CHEST_TYPES: Array[RoomData.RoomType] = [RoomData.RoomType.START, RoomData.RoomType.EXIT]

var chests: Dictionary = {}

var _room_manager: RoomManager
var _floor_manager: FloorManager


## Connects after Main2d's own `room_revealed` handler, so the group is already shown.
func setup(room_manager: RoomManager, door_turn_system: DoorTurnSystem, floor_manager: FloorManager) -> void:
	_room_manager = room_manager
	_floor_manager = floor_manager
	door_turn_system.room_revealed.connect(_on_room_revealed)
	for hero in ManagerLocator.get_heroes():
		hero.zone_changed.connect(_on_hero_zone_changed)


func _on_room_revealed(group_id: String, _cells: Array[Vector2i]) -> void:
	for zone_id in _room_manager.get_group_zone_ids(group_id):
		if _room_manager.get_zone_kind(zone_id) != "room" or chests.has(zone_id):
			continue
		var type := _room_manager.get_room_type(zone_id)
		if type in NO_CHEST_TYPES:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([_floor_manager.map_seed if _floor_manager else 0, zone_id, "chest"])
		if rng.randf() >= _chance_for(type):
			continue
		var item := roll_item(rng)
		if item == null:
			continue
		var chest := spawn_chest(zone_id, item)
		for hero in ManagerLocator.get_heroes():
			if hero.current_zone_id == zone_id:
				chest.try_open()


func spawn_chest(zone_id: String, item: ItemData) -> Chest:
	var chest := Chest.new()
	chest.setup(item, zone_id)
	chest.position = _room_manager.get_center(zone_id) + CHEST_OFFSET
	add_child(chest)
	chests[zone_id] = chest
	return chest


func _on_hero_zone_changed(zone_id: String) -> void:
	var chest: Chest = chests.get(zone_id)
	if chest != null and is_instance_valid(chest) and chest.is_closed():
		chest.try_open()


func _chance_for(type: RoomData.RoomType) -> float:
	if _floor_manager:
		return _floor_manager.loot_chance(type)
	return 1.0 if type == RoomData.RoomType.LOOT else 0.0


static func roll_item(rng: RandomNumberGenerator) -> ItemData:
	var catalog := ItemCatalog.get_default()
	return catalog.pick(rng) if catalog else null
