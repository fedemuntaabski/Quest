extends Resource
class_name FloorConfig

## FloorConfig: per-floor difficulty scaling for a run. Floor indices are
## 1-based; floor 1 is always the unscaled baseline. All growth is linear in
## (floor_index - 1). Consumed by FloorManager — gameplay systems ask
## FloorManager, never this Resource directly.

@export_group("Progression")
## Floors in a run. Clearing this floor ends the run with the normal victory.
@export var max_floors: int = 5
## Dust granted when descending to a new floor (floor 2+).
@export var dust_bonus_on_descend: int = 10

@export_group("Map")
## Rooms on floor 1 (MapGenerator room_count); grows per floor up to max.
## Session 7: 6 → 8 (max 12 → 14), bigger floors, still a tree (no loops).
@export var base_room_count: int = 8
@export var rooms_per_floor: float = 1.0
@export var max_room_count: int = 14
## MapGenerator branch_chance: higher = more side branches/dead ends.
@export var base_branch_chance: float = 0.25
@export var branch_chance_per_floor: float = 0.1

@export_group("Discovery")
## Dust granted every time a new room is discovered (door opened), whether or
## not an invasion happens. Tuned so a floor lights some rooms, not all
## (energizing costs RoomZone.get_power_cost(), base 10; run starts with 20 dust).
## Session 7: 2 → 4 (the start room is now lit for free, rooms can be switched
## off for a refund, and floors are bigger).
@export var dust_per_discovery: int = 4
## +X dust per discovery per floor (fractional, floored).
@export var dust_per_discovery_growth: float = 0.5

@export_group("Enemy scaling")
## +X enemy max HP per floor (0.25 = +25% each floor).
@export var enemy_hp_growth: float = 0.25
## +X enemy damage (hero contact + module attacks) per floor.
@export var enemy_damage_growth: float = 0.2

@export_group("Wave scaling")
## Flat bonus added to the per-door invasion chance per floor.
@export var invasion_chance_bonus_per_floor: float = 0.05
## Extra enemies per invasion per floor (fractional, floored).
@export var extra_invasion_enemies_per_floor: float = 0.5
@export var extraction_spawn_interval: float = 5.0
## Seconds shaved off the extraction wave timer per floor.
@export var extraction_interval_reduction_per_floor: float = 0.5
@export var min_extraction_spawn_interval: float = 2.0


func enemy_hp_multiplier(floor_index: int) -> float:
	return 1.0 + enemy_hp_growth * _steps(floor_index)


func enemy_damage_multiplier(floor_index: int) -> float:
	return 1.0 + enemy_damage_growth * _steps(floor_index)


func invasion_chance_bonus(floor_index: int) -> float:
	return invasion_chance_bonus_per_floor * _steps(floor_index)


func extra_invasion_enemies(floor_index: int) -> int:
	return int(floor(extra_invasion_enemies_per_floor * _steps(floor_index)))


func extraction_interval(floor_index: int) -> float:
	return maxf(min_extraction_spawn_interval, extraction_spawn_interval - extraction_interval_reduction_per_floor * _steps(floor_index))


func room_count(floor_index: int) -> int:
	return mini(max_room_count, base_room_count + int(floor(rooms_per_floor * _steps(floor_index))))


func branch_chance(floor_index: int) -> float:
	return clampf(base_branch_chance + branch_chance_per_floor * _steps(floor_index), 0.0, 1.0)


func discovery_dust(floor_index: int) -> int:
	return dust_per_discovery + int(floor(dust_per_discovery_growth * _steps(floor_index)))


func _steps(floor_index: int) -> int:
	return maxi(floor_index - 1, 0)
