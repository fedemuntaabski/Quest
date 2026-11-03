extends Resource
class_name ResearchEntry

## One research node (ResearchConfig.entries). Paid once per run in Saber
## via ResourceManager.research(); the effect is read by the system it
## touches through ResourceManager.get_bonus(effect) / is_unlocked(building).

enum Effect {
	UNLOCK_BUILDING,       ## `building` can be built (locked until researched)
	WORKSHOP_YIELD_PCT, ## +value (0.25 = +25%) to the summed workshop yield
	DEFENSE_DAMAGE,       ## +value damage per defense shot
	LIGHT_COST,          ## -value embers to light a room (never below 1)
	DISCOVERY_EMBERS,      ## +value embers per discovered room
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: int = 10
## Id of the entry that must be researched first ("" = none, tier 1).
@export var prerequisite: String = ""
@export var effect: Effect = Effect.UNLOCK_BUILDING
@export var value: float = 0.0
## Only for UNLOCK_BUILDING.
@export var building: Building.BuildingType = Building.BuildingType.BALLESTA


func describe_effect() -> String:
	match effect:
		Effect.UNLOCK_BUILDING:
			return "Desbloquea: %s" % Building.CATALOG[building]["label"]
		Effect.WORKSHOP_YIELD_PCT:
			return "+%d%% producción de talleres" % roundi(value * 100.0)
		Effect.DEFENSE_DAMAGE:
			return "+%d de daño de defensas" % roundi(value)
		Effect.LIGHT_COST:
			return "-%d Brasas al encender una sala" % roundi(value)
		Effect.DISCOVERY_EMBERS:
			return "+%d en Brasas por sala descubierta" % roundi(value)
	return ""
