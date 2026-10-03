extends Resource
class_name DoorRollConfig

## DoorRollConfig: what opening a door does. Every opening (room or loop
## corridor) rolls a threat whose chance grows with the doors already opened on
## the floor, and always pays a reward: dust (rooms only) + one random resource.
## Floors are 1-based; growth is linear in (floor - 1). Pure functions, so tests
## and BalanceSim read them without a scene.

@export_group("Threat")
## P(enemies) = clamp(base + per_door * doors_opened + per_floor * (floor - 1), 0, max).
@export_range(0.0, 1.0) var base_chance: float = 0.1
@export_range(0.0, 1.0) var chance_per_door: float = 0.06
@export_range(0.0, 1.0) var chance_per_floor: float = 0.05
@export_range(0.0, 1.0) var max_chance: float = 0.85
## Enemies per threat: base + doors_opened / doors_per_extra_enemy + extra_per_floor * (floor - 1), floored.
@export var base_enemy_count: int = 1
@export var doors_per_extra_enemy: float = 5.0
@export var extra_enemies_per_floor: float = 0.34

@export_group("Reward")
## Dust paid by a door that reveals a room: base + growth * (floor - 1), floored.
@export var dust_base: int = 4
@export var dust_per_floor: float = 0.5
## Plus one of the resources below, picked by weight, `bonus_base` + `bonus_per_floor` * (floor - 1).
@export var bonus_base: int = 2
@export var bonus_per_floor: float = 0.5
@export var bonus_resources: PackedStringArray = PackedStringArray(["industry", "food", "science"])
## One Vector3 per floor (index = floor - 1, past the end reuses the last) = weights
## for bonus_resources in order. Early floors lean on Industria, later on Ciencia.
@export var bonus_weights_by_floor: Array[Vector3] = [Vector3(3, 2, 1), Vector3(2, 2, 2), Vector3(2, 2, 3)]


func threat_chance(doors_opened: int, floor_index: int) -> float:
	return clampf(base_chance + chance_per_door * doors_opened + chance_per_floor * _steps(floor_index), 0.0, max_chance)


func enemy_count(doors_opened: int, floor_index: int) -> int:
	return maxi(1, base_enemy_count + int(floor(doors_opened / doors_per_extra_enemy)) + int(floor(extra_enemies_per_floor * _steps(floor_index))))


func dust_reward(floor_index: int) -> int:
	return dust_base + int(floor(dust_per_floor * _steps(floor_index)))


func bonus_amount(floor_index: int) -> int:
	return bonus_base + int(floor(bonus_per_floor * _steps(floor_index)))


## The resource key of this door's extra reward (weights of the floor).
func roll_bonus_resource(floor_index: int, rng: RandomNumberGenerator) -> String:
	if bonus_resources.is_empty():
		return ""
	var weights := Vector3.ONE
	if not bonus_weights_by_floor.is_empty():
		weights = bonus_weights_by_floor[clampi(floor_index - 1, 0, bonus_weights_by_floor.size() - 1)]
	var total := 0.0
	for i in bonus_resources.size():
		total += maxf(weights[i] if i < 3 else 1.0, 0.0)
	if total <= 0.0:
		return bonus_resources[0]
	var pick := rng.randf() * total
	for i in bonus_resources.size():
		pick -= maxf(weights[i] if i < 3 else 1.0, 0.0)
		if pick < 0.0:
			return bonus_resources[i]
	return bonus_resources[bonus_resources.size() - 1]


func _steps(floor_index: int) -> int:
	return maxi(floor_index - 1, 0)
