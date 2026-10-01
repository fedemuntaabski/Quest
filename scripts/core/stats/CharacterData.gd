extends Resource
class_name CharacterData

## CharacterData — static definition of a selectable hero archetype.
## Consumed by CharacterDatabase for lookup and by the character-select UI for display.

@export var character_id: String = ""
@export var display_name: String = "Hero"
## Short role line for the hero-select screen ("Tanque y Provocador").
@export var role: String = ""
@export var description: String = ""
@export var portrait: Texture2D = null
@export var profile_bg: Texture2D = null

@export var base_hp: int = 20

@export_group("Combat")
## Damage dealt to every enemy inside the hero's HitboxComponent per tick.
@export var attack_damage: int = 3
## Seconds between auto-attack ticks.
@export var attack_interval: float = 1.0
## Radius (px) of the auto-attack AoE (Player/Hitbox circle). Default = the scene's 160.
@export var attack_range: float = 160.0
@export_group("")

@export var passive_ability_name: String = ""
@export var passive_ability_desc: String = ""
@export var active_ability_name: String = ""

@export var sprite_frames: SpriteFrames = null
