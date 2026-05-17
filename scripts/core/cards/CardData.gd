extends Resource
class_name CardData

@export var id: String = ""
@export var display_name: String = "Card"
@export var description: String = ""
@export var category: String = "strength" # strength, agility, magic
@export var rarity: String = "common"
@export var card_type: String = "melee" # melee, ranged, magic, buff, debuff
@export var target_type: String = "enemy" # enemy, self, ally, ground
@export var targeting_profile: String = ""
@export var stat_key: String = "strength"
@export var base_damage: int = 0
@export var damage_scaling: float = 1.0
@export var range: int = 1
@export var cooldown: int = 0
@export var icon: Texture2D
@export var effects: Array[Resource] = []
@export var reward_weight: float = 1.0
@export var unlock_tags: Array[String] = []
@export var vfx_id: String = ""
@export var sfx_id: String = ""
@export var tags: Array[String] = []
