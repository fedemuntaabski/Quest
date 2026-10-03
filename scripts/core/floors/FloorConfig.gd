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
## Session 7: 6 → 8 (max 12 → 14), bigger floors. Loops/room types never
## change the room count.
@export var base_room_count: int = 8
@export var rooms_per_floor: float = 1.0
@export var max_room_count: int = 14
## MapGenerator branch_chance: higher = more side branches/dead ends.
@export var base_branch_chance: float = 0.25
@export var branch_chance_per_floor: float = 0.1
## Session 11: loops (MapGenerator.add_loops) — extra corridors between rooms
## in adjacent slots the tree didn't join. Each of max_loops() quota slots rolls
## loop_chance(); a map without a valid pair just gets fewer/no loops.
@export var base_loop_chance: float = 0.5
@export var loop_chance_per_floor: float = 0.1
@export var base_max_loops: int = 1
## +X loop slots per floor (fractional, floored).
@export var max_loops_per_floor: float = 0.5

@export_group("Room types")
## One RoomTypeRule per special type (Rest/Loot/Elite), applied in order by
## MapGenerator.assign_room_types. Start/Exit are fixed by the generator;
## every other room is Combat.
@export var room_types: Array[RoomTypeRule] = []

@export_group("Loot")
## Chance that a room WITHOUT a RoomTypeRule (plain Combat rooms) holds a chest.
@export_range(0.0, 1.0) var default_loot_chance: float = 0.08
## Chance of an item as the floor's completion reward (straight to the stash).
@export_range(0.0, 1.0) var floor_end_loot_chance: float = 1.0

@export_group("Doors")
## Threat roll and reward of every opened door (session bucle-7). Discovery dust
## lives here now (door_roll.dust_reward), tuned so a floor lights some rooms,
## not all (energizing costs RoomZone.get_power_cost(), base 10 and rising).
@export var door_roll: DoorRollConfig = preload("res://resources/floors/door_roll_config.tres")

@export_group("Energy")
## Extra dust per room already energized (the free start room does not count).
@export var power_cost_step: int = 2

@export_group("Enemy scaling")
## +X enemy max HP per floor (0.25 = +25% each floor).
@export var enemy_hp_growth: float = 0.25
## +X enemy damage (hero contact + module attacks) per floor.
@export var enemy_damage_growth: float = 0.2

@export_group("Enemy pools")
## One EnemyPool per floor (index = floor - 1; floors past the end reuse the last).
@export var enemy_pools: Array[EnemyPool] = []

@export_group("Nexo")
## Nexo hit points: raiders wear them down, 0 = the usual defeat.
@export var nexo_max_hp: int = 100
## Speed of the hero carrying the Nexo (0.85 = 15 % slower).
@export_range(0.1, 1.0) var carrier_speed_mult: float = 0.85

@export_group("Enemy cap")
## Max enemies alive at once, per floor (index = floor - 1, past the end reuses the last).
## Door invasions and extraction waves stop spawning at the cap.
@export var max_enemies_by_floor: PackedInt32Array = PackedInt32Array([6, 8, 10, 12, 14])

@export_group("Enemy roles")
## Share of spawns that are RAIDERS (go for the Nexo); the rest are HUNTERS.
## Index = floor - 1, floors past the end reuse the last. Early floors: almost only hunters.
@export var raider_ratio_by_floor: PackedFloat32Array = PackedFloat32Array([0.05, 0.2, 0.35, 0.5, 0.6])
## A raider never spawns where it could reach the Nexo sooner than this (seconds
## at its own speed); that spawn becomes a hunter. Time for the player to react.
@export var raider_min_arrival_sec: float = 4.0

@export_group("Wave scaling")
## Extraction waves (after the Nexo is taken): stage 0 starts at pickup and the
## stage rises every extraction_stage_sec up to extraction_stage_count - 1, so the
## waves keep growing until the exit. Each wave = wave_base + floor(wave_growth * stage)
## enemies spread over dark rooms; the gap between waves is extraction_interval(floor)
## minus extraction_stage_interval_step per stage (never below min_extraction_spawn_interval).
@export var extraction_spawn_interval: float = 5.0
## Seconds shaved off the extraction wave timer per floor.
@export var extraction_interval_reduction_per_floor: float = 0.5
@export var min_extraction_spawn_interval: float = 2.0
@export var extraction_stage_sec: float = 20.0
@export var extraction_stage_count: int = 4
@export var extraction_stage_interval_step: float = 0.5
@export var extraction_wave_base: int = 1
@export var extraction_wave_growth: float = 1.0


func enemy_hp_multiplier(floor_index: int) -> float:
	return 1.0 + enemy_hp_growth * _steps(floor_index)


func enemy_damage_multiplier(floor_index: int) -> float:
	return 1.0 + enemy_damage_growth * _steps(floor_index)


## The roster of `floor_index` (clamped to the configured pools); null if none.
func enemy_pool(floor_index: int) -> EnemyPool:
	if enemy_pools.is_empty():
		return null
	return enemy_pools[clampi(floor_index - 1, 0, enemy_pools.size() - 1)]


func raider_ratio(floor_index: int) -> float:
	if raider_ratio_by_floor.is_empty():
		return 0.0
	return clampf(raider_ratio_by_floor[clampi(floor_index - 1, 0, raider_ratio_by_floor.size() - 1)], 0.0, 1.0)


## Max enemies alive at once on `floor_index` (0 entries = no cap).
func max_enemies(floor_index: int) -> int:
	if max_enemies_by_floor.is_empty():
		return 1 << 30
	return max_enemies_by_floor[clampi(floor_index - 1, 0, max_enemies_by_floor.size() - 1)]


## Seconds between extraction waves on `floor_index` at the start (stage 0).
func extraction_interval(floor_index: int) -> float:
	return maxf(min_extraction_spawn_interval, extraction_spawn_interval - extraction_interval_reduction_per_floor * _steps(floor_index))


## Seconds between waves at extraction `stage` (shrinks per stage, floored).
func extraction_stage_interval(floor_index: int, stage: int) -> float:
	return maxf(min_extraction_spawn_interval, extraction_interval(floor_index) - extraction_stage_interval_step * stage)


## Enemies per extraction wave at `stage`.
func extraction_wave_size(stage: int) -> int:
	return maxi(1, extraction_wave_base + int(floor(extraction_wave_growth * stage)))


func room_count(floor_index: int) -> int:
	return mini(max_room_count, base_room_count + int(floor(rooms_per_floor * _steps(floor_index))))


func branch_chance(floor_index: int) -> float:
	return clampf(base_branch_chance + branch_chance_per_floor * _steps(floor_index), 0.0, 1.0)


func loop_chance(floor_index: int) -> float:
	return clampf(base_loop_chance + loop_chance_per_floor * _steps(floor_index), 0.0, 1.0)


func max_loops(floor_index: int) -> int:
	return maxi(0, base_max_loops + int(floor(max_loops_per_floor * _steps(floor_index))))


## The rule for `type`, or null (Combat/Start/Exit, or not configured).
func get_room_type_rule(type: RoomData.RoomType) -> RoomTypeRule:
	for rule in room_types:
		if rule and rule.type == type:
			return rule
	return null


## Chest chance of a room type: its rule's loot_chance, else default_loot_chance.
## Start and Exit rooms never hold one.
func loot_chance(type: RoomData.RoomType) -> float:
	if type == RoomData.RoomType.START or type == RoomData.RoomType.EXIT:
		return 0.0
	var rule := get_room_type_rule(type)
	return rule.loot_chance if rule else default_loot_chance


## Dust a door that reveals a room pays (DoorRollConfig "Reward").
func discovery_dust(floor_index: int) -> int:
	return door_roll.dust_reward(floor_index)


func _steps(floor_index: int) -> int:
	return maxi(floor_index - 1, 0)
