extends Resource
class_name CardData

@export var id: String = ""
@export var display_name: String = "Card"
@export var description: String = ""
@export var card_type: String = "melee" # melee, ranged, magic, buff, debuff
@export var target_type: String = "enemy" # enemy, self, ally, ground
@export var stat_key: String = "strength"
@export var base_damage: int = 0
@export var damage_scaling: float = 1.0
@export var range: int = 1
@export var cooldown: int = 0
@export var icon: Texture2D
@export var effects: Array[Resource] = []
@export var tags: Array[String] = []
