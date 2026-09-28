extends Resource
class_name ResearchEntry

## One research node (ResearchConfig.entries). Paid once per run in Ciencia
## via ResourceManager.research(); the effect is read by the system it
## touches through ResourceManager.get_bonus(effect) / is_unlocked(module).

enum Effect {
	UNLOCK_MODULE,       ## `module` can be built (locked until researched)
	GENERATOR_YIELD_PCT, ## +value (0.25 = +25%) to the summed generator yield
	TURRET_DAMAGE,       ## +value damage per turret shot
	POWER_COST,          ## -value dust to light a room (floor 1)
	DISCOVERY_DUST,      ## +value dust per discovered room
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 10
## Id of the entry that must be researched first ("" = none, tier 1).
@export var prerequisite: String = ""
@export var effect: Effect = Effect.UNLOCK_MODULE
@export var value: float = 0.0
## Only for UNLOCK_MODULE.
@export var module: Module.ModuleType = Module.ModuleType.TURRET


func describe_effect() -> String:
	match effect:
		Effect.UNLOCK_MODULE:
			return "Desbloquea: %s" % Module.CATALOG[module]["label"]
		Effect.GENERATOR_YIELD_PCT:
			return "+%d%% producción de generadores" % roundi(value * 100.0)
		Effect.TURRET_DAMAGE:
			return "+%d de daño de torretas" % roundi(value)
		Effect.POWER_COST:
			return "-%d Polvo al encender una sala" % roundi(value)
		Effect.DISCOVERY_DUST:
			return "+%d Polvo por sala descubierta" % roundi(value)
	return ""
