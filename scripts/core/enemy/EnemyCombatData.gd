extends Resource
class_name EnemyCombatData

@export var base_damage: int = 1
@export var attack_range: int = 1
@export var attack_stat: String = "strength"

@export var movement: int = 1
@export var move_step_time: float = 0.12

@export var forced_miss_chance: float = 0.0