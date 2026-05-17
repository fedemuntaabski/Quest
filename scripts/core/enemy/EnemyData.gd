extends Resource
class_name EnemyData

@export var enemy_id: String = ""
@export var enemy_name: String = "Enemy"

@export var max_hp: int = 10
@export var strength: int = 1
@export var magic: int = 0
@export var dexterity: int = 0

@export var base_damage: int = 2
@export var attack_range: int = 1
@export var attack_stat: String = "strength"
@export var movement: int = 1
@export var forced_miss_chance: float = 0.0

@export var move_step_time: float = 0.12
@export var reward_gold: int = 5

@export var ai_type: String = "melee_chase"
@export var sprite_texture: Texture2D
@export var base_tint: Color = Color(1, 1, 1, 1)
@export var target_tint: Color = Color(1.0, 0.6, 0.6, 1.0)

@export var is_boss: bool = false
@export var tags: Array[String] = []
@export var extra_stats: Dictionary = {}
