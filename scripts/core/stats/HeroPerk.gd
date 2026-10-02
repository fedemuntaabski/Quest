extends Resource
class_name HeroPerk

## HeroPerk: a class upgrade offered to one hero as a 1-of-2 choice at hero
## level `unlock_level` (3 and 5). Perks of the same `exclusive_group` exclude
## each other. `mods` only uses MOD_KEYS and holds deltas; PlayerStats adds them
## as the third stat layer (base -> level -> perks/equipment) and HeroAbilities
## adds the ability keys on top of the AbilityData numbers.

## Stat deltas (CharacterStats) and ability deltas (HeroAbilities).
const MOD_KEYS: Array[String] = [
	"hp", "attack_damage", "attack_interval", "attack_range",
	"active_cooldown", "active_value", "active_duration",
	"passive_value", "passive_radius",
]
const STAT_KEYS: Array[String] = ["hp", "attack_damage", "attack_interval", "attack_range"]
const MOD_LABELS := {
	"hp": "Vida", "attack_damage": "Daño", "attack_interval": "s Intervalo", "attack_range": "px Alcance",
	"active_cooldown": "s Enfriamiento", "active_value": "Potencia de la activa", "active_duration": "s Duración",
	"passive_value": "Potencia de la pasiva", "passive_radius": "px Radio de la pasiva",
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Hero level from which it is offered.
@export var unlock_level: int = 3
## Same group = pick one.
@export var exclusive_group: StringName = &""
@export var mods: Dictionary = {}


## "-5 s Enfriamiento · +20 px Alcance" from `mods`.
func describe_mods() -> String:
	var parts: Array[String] = []
	for key: String in MOD_KEYS:
		if mods.has(key):
			parts.append(_format(key, float(mods[key])))
	return " · ".join(parts)


static func _format(key: String, value: float) -> String:
	if key in ["hp", "attack_damage", "attack_range", "passive_radius"] or (absf(value) >= 1.0 and is_equal_approx(value, roundf(value))):
		return "%+d %s" % [roundi(value), MOD_LABELS[key]]
	return "%+.2f %s" % [value, MOD_LABELS[key]]
