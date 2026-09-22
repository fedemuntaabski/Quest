extends Resource
class_name CharacterData

## CharacterData — static definition of a selectable hero archetype.
## Consumed by CharacterDatabase for lookup and by the character-select UI for display.

@export var character_id: String = ""
@export var display_name: String = "Hero"
@export var description: String = ""
@export var portrait: Texture2D = null
@export var profile_bg: Texture2D = null

@export var base_hp: int = 20

@export var passive_ability_name: String = ""
@export var passive_ability_desc: String = ""
@export var active_ability_name: String = ""

@export var sprite_frames: SpriteFrames = null
