extends Resource
class_name FloorTheme

## FloorTheme (progresion-10): identity + difficulty of one floor of the run.
## Listed in RunCurve.floors (index = floor - 1). FloorConfig delegates its
## per-floor numbers here when a RunCurve is set; DifficultyConfig multiplies
## on top (FloorManager).

@export var display_name: String = ""
## Modulate of the drawn map (MapTileRenderer) and of the dark canvas.
@export var tint: Color = Color.WHITE
## Background music (AudioDirector); a missing file plays silence.
@export_file("*.ogg", "*.mp3", "*.wav") var music_path: String = ""

@export_group("Enemies")
@export var enemy_pool: EnemyPool
@export var hp_mult: float = 1.0
@export var damage_mult: float = 1.0
## Multiplies the door threat chance (DoorRollConfig).
@export var threat_mult: float = 1.0
## Max enemies alive at once.
@export var max_enemies: int = 8
## Share of spawns that are raiders (go for the Nexo).
@export_range(0.0, 1.0) var raider_ratio: float = 0.2
## Guards the exit room (EnemyManager.spawn_boss); null = no boss on this floor.
@export var boss: EnemyType

@export_group("Trap")
## Floor trap in corridors (HazardSpawner): one-shot, hurts the first hero crossing.
@export var trap_name: String = ""
@export var trap_damage: int = 0
@export_range(0.0, 1.0) var trap_chance: float = 0.0
@export var trap_color: Color = Color(0.8, 0.8, 0.8)
