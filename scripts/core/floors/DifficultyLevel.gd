extends Resource
class_name DifficultyLevel

## DifficultyLevel (progresion-10): multipliers over the RunCurve for one
## difficulty (DifficultyConfig.levels). 1.0 = Normal.

@export var id: String = "normal"
@export var display_name: String = "Normal"
@export_multiline var description: String = ""
@export var hp_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var threat_mult: float = 1.0
@export var extra_max_enemies: int = 0
@export var nexo_hp_mult: float = 1.0
## Starting resources of the run (ResourceManager.reset_resources).
@export var start_resource_mult: float = 1.0
