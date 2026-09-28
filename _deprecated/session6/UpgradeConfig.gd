extends Resource
class_name UpgradeConfig

## UpgradeConfig: in-run hero upgrades bought from the character popup
## ("Mejoras"). Paid with `cost_resource` (Ciencia by default — it had no sink),
## reset every run (PlayerStats.reset_run_upgrades). Separate from the meta
## Oro store in the pause menu, which persists in the save.

const STAT_KEYS: Array[String] = ["hp", "damage", "attack_speed"]
const LABELS := {
	"hp": "Vida máxima",
	"damage": "Daño",
	"attack_speed": "Velocidad de ataque",
}

@export var cost_resource: String = "science"
@export var max_level: int = 5

@export_group("Cost curve")
## cost(level) = round(base_cost * cost_growth ^ level) → 5, 8, 11, 17, 25.
@export var base_cost: int = 5
@export var cost_growth: float = 1.5

@export_group("Bonus per level")
@export var hp_per_level: int = 4
@export var damage_per_level: int = 1
## Fraction of the base attack interval removed per level (0.1 = 10%).
@export var attack_speed_per_level: float = 0.1
@export var min_attack_interval: float = 0.2


func get_cost(level: int) -> int:
	return roundi(base_cost * pow(cost_growth, maxi(level, 0)))


func is_maxed(level: int) -> bool:
	return level >= max_level


func damage_at(base_damage: int, level: int) -> int:
	return base_damage + damage_per_level * maxi(level, 0)


func interval_at(base_interval: float, level: int) -> float:
	return maxf(min_attack_interval, base_interval * (1.0 - attack_speed_per_level * maxi(level, 0)))
