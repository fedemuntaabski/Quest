extends Resource
class_name CharacterData

## CharacterData — static definition of a selectable hero archetype.
## Consumed by CharacterDatabase for lookup and by the character-select UI for display.

@export var character_id: String = ""
@export var display_name: String = "Hero"
@export var description: String = ""
@export var portrait: Texture2D = null

@export var base_hp: int = 20
@export var base_str: int = 1
@export var base_mag: int = 1
@export var base_dex: int = 1

@export var base_ap: int = 2
@export var move_range_per_ap: int = 3

@export var sprite_frames: SpriteFrames = null
