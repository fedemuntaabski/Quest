extends Resource
class_name EnemyData

@export var enemy_id: String
@export var enemy_name: String


# Importe de los .gd de la carpeta de enemy, cada uno con responsabilidades específicas (combat, stats, visual)
@export var combat: EnemyCombatData
@export var stats: EnemyStatsData
@export var visual: EnemyVisualData

@export var ai_type: String = "melee_chase"

@export var reward_gold: int = 0

@export var is_boss: bool = false

@export var tags: Array[String] = []