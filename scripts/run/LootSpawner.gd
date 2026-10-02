class_name LootSpawner
extends Node2D

## Loot rooms show a floating chest at the spot where the Nexo would sit when
## they are discovered. The item is rolled by rarity, seeded with (floor seed,
## room) so a floor always holds the same loot, and recorded as a find.

const CHEST_OFFSET := Vector2(0, -56)
const PICKUP_SCENE := preload("res://scenes/world/Pickup.tscn")

var _room_manager: RoomManager
var _floor_manager: FloorManager


## Connects after Main2d's own `room_revealed` handler, so the group is already shown.
func setup(room_manager: RoomManager, door_turn_system: DoorTurnSystem, floor_manager: FloorManager) -> void:
	_room_manager = room_manager
	_floor_manager = floor_manager
	door_turn_system.room_revealed.connect(_on_room_revealed)


func _on_room_revealed(group_id: String, _cells: Array[Vector2i]) -> void:
	for zone_id in _room_manager.get_group_zone_ids(group_id):
		if _room_manager.get_room_type(zone_id) != RoomData.RoomType.LOOT:
			continue
		var chest := PICKUP_SCENE.instantiate() as Pickup
		chest.kind = Pickup.Kind.CHEST
		chest.position = _room_manager.get_center(zone_id) + CHEST_OFFSET
		chest.z_index = 2
		chest.item = _roll_item(zone_id)
		add_child(chest)
		var player_stats := ManagerLocator.get_player_stats()
		if player_stats:
			player_stats.add_found_item(chest.item)


func _roll_item(zone_id: String) -> ItemData:
	var catalog := ItemCatalog.get_default()
	if catalog == null:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_floor_manager.map_seed if _floor_manager else 0, zone_id, "chest"])
	return catalog.pick(rng)
