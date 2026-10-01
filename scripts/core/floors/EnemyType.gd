extends Resource
class_name EnemyType

## EnemyType: one spawnable enemy — art + stat multipliers over an Enemy.Variant
## behaviour. Listed in EnemyPools (FloorConfig.enemy_pools) so each floor's
## roster is data. Multipliers stack with the floor's and Elite rooms'.

@export var id: String = ""
@export var display_name: String = ""
## Enemy.Variant value: 0 Swarm, 1 Sapper, 2 Hunter (AI + base stats in Enemy.VARIANT_CONFIG).
## An int (not the enum) so this Resource doesn't depend on Enemy.
@export_enum("Swarm", "Sapper", "Hunter") var behavior: int = 0
@export var sprite_frames: SpriteFrames
@export var hp_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var speed_mult: float = 1.0
## On top of ArtConfig.ART_SCALE (e.g. 1.5 for a boss-sized Tiny Creature).
@export var visual_scale: float = 1.0

@export_group("Role")
## HUNTER chases heroes; RAIDER ignores them and goes for the Nexo. Decides the
## destination; `behavior` keeps deciding base stats (and the Sapper's module hunt).
enum Role { HUNTER, RAIDER }
@export var role: Role = Role.HUNTER
## HUNTER: heroes closer than this (px) are chased directly.
@export var aggro_range: float = 320.0
## Distance (px) at which the target (hero / Nexo) counts as in range.
@export var attack_range: float = 40.0
## 0 = the variant's contact_damage (current stats untouched); >0 overrides it.
@export var damage_vs_heroes: int = 0
## Damage per AttackTimer tick to the Nexo (RAIDER only).
@export var damage_vs_nexus: int = 0
