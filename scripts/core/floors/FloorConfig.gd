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


func _steps(floor_index: int) -> int:
	return maxi(floor_index - 1, 0)
