extends Resource
class_name UpgradeConfig

## UpgradeConfig: in-run hero level-ups bought from the character popup
## ("Subir de nivel"). Each level raises every STAT_KEYS stat by its per-level
## bonus. Paid with `cost_resource` (Comida in the shipped .tres since session
## 7), reset every run (PlayerStats.reset_run_upgrades).

const STAT_KEYS: Array[String] = ["hp", "damage", "attack_speed"]
const LABELS := {
	"hp": "Vida máxima",
	"damage": "Daño",
	"attack_speed": "Velocidad de ataque",
}

@export var cost_resource: String = "food"
## Level-ups per run (hero level 1 → 1 + max_level).
@export var max_level: int = 5

@export_group("Cost curve")
## cost(level) = round(base_cost * cost_growth ^ level) → 8, 11, 16, 22, 31.
@export var base_cost: int = 8
@export var cost_growth: float = 1.4

@export_group("Bonus per level")
@export var hp_per_level: int = 4
@export var damage_per_level: int = 1
## Fraction of the base attack interval removed per level (0.1 = 10%).
@export var attack_speed_per_level: float = 0.1
@export var min_attack_interval: float = 0.2


@export_group("Healing")
## Comida per missing HP when healing from the character popup.
@export var heal_cost_per_hp: float = 0.15


## Comida to restore `missing_hp` (0 when nothing is missing).
func heal_cost(missing_hp: int) -> int:
	return 0 if missing_hp <= 0 else maxi(1, ceili(missing_hp * heal_cost_per_hp))


func get_cost(level: int) -> int:
	return roundi(base_cost * pow(cost_growth, maxi(level, 0)))


func is_maxed(level: int) -> bool:
	return level >= max_level


func damage_at(base_damage: int, level: int) -> int:
	return base_damage + damage_per_level * maxi(level, 0)


func interval_at(base_interval: float, level: int) -> float:
	return maxf(min_attack_interval, base_interval * (1.0 - attack_speed_per_level * maxi(level, 0)))
