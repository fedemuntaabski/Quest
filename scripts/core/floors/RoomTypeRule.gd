extends Resource
class_name RoomTypeRule

## RoomTypeRule: how often a special room type appears (MapGenerator.
## assign_room_types) and what it does. One per type in FloorConfig.room_types.
## Behavior is read from these fields, never matched on `type`, so a type is
## pure data. Per-floor growth is linear in (floor_index - 1), like FloorConfig.

@export var type: RoomData.RoomType = RoomData.RoomType.COMBAT

@export_group("Generation")
## Chance each of the max_count_at() quota slots actually becomes this type.
@export var chance: float = 0.5
@export var chance_per_floor: float = 0.0
@export var max_count: int = 1
## +X quota slots per floor (fractional, floored).
@export var max_count_per_floor: float = 0.0

@export_group("Effects")
## One-time reward on discovery. Resource key: industry/food/science/dust.
@export var reward_resource: String = ""
@export var reward_amount: int = 0
@export var reward_per_floor: float = 0.0
## Hero HP restored once, on discovery.
@export var heal_on_discovery: int = 0
## Enemies never spawn here (door-open invasions and extraction waves).
@export var blocks_spawns: bool = false
## Multipliers for enemies spawned in this room (on top of floor scaling).
@export var enemy_hp_mult: float = 1.0
@export var enemy_damage_mult: float = 1.0
## Extra MAJOR build slots once the room is lit (Generator room: 2 majors).
@export var extra_major_slots: int = 0


func chance_at(floor_index: int) -> float:
	return clampf(chance + chance_per_floor * _steps(floor_index), 0.0, 1.0)


func max_count_at(floor_index: int) -> int:
	return maxi(0, max_count + int(floor(max_count_per_floor * _steps(floor_index))))


func reward_at(floor_index: int) -> int:
	return maxi(0, reward_amount + int(floor(reward_per_floor * _steps(floor_index))))


func _steps(floor_index: int) -> int:
	return maxi(floor_index - 1, 0)
