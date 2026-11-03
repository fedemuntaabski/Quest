extends Resource
class_name BuildingDef

## Data of one buildable building (`resources/buildings/*.tres`). Building.CATALOG is
## built from these (see Building._build_catalog), so call sites keep reading dicts.

## Building.BuildingType value (int: serialized, keep stable).
@export var type: int = 0
@export var display_name: String = ""
@export_multiline var description: String = ""
## Building.SlotType value: 0 = MAJOR (1 per room), 1 = MINOR.
@export var slot: int = 1
@export_range(1, 3) var tier: int = 1
@export var hp: int = 15
## Hierro; the real price grows with the built count (BuildingCostCurve).
@export var base_cost: int = 5
## False = works in unlit rooms too.
@export var requires_light: bool = true
@export var scene_path: String = "res://scenes/world/Building.tscn"
@export var icon_path: String = ""
@export_group("Effect")
## Workshops: resource key ("iron"/"food"/"lore") and amount per door.
@export var resource: String = ""
@export var yield_amount: int = 0
## Ballesta / Catapulta.
@export var damage: int = 0
@export var fire_rate: float = 1.0
## > 0: the shot also hits every enemy within this many px of the target.
@export var splash_radius: float = 0.0
## Brasero.
@export var slow_factor: float = 1.0
@export var slow_duration: float = 0.0
## Trampa de pinchos: damage dealt once to each enemy that enters the room.
@export var spike_damage: int = 0


## Same shape the old const dict had, plus the new fields.
func to_dict() -> Dictionary:
	var d := {
		"hp": hp, "label": display_name, "slot": slot, "cost": base_cost, "scene": scene_path,
		"tier": tier, "requires_light": requires_light, "icon": icon_path, "description": description,
		"iron": 0, "food": 0, "lore": 0,
	}
	if resource != "":
		d[resource] = yield_amount
	if damage > 0:
		d["damage"] = damage
		d["fire_rate"] = fire_rate
		d["splash_radius"] = splash_radius
	if slow_duration > 0.0:
		d["slow_factor"] = slow_factor
		d["slow_duration"] = slow_duration
	if spike_damage > 0:
		d["spike_damage"] = spike_damage
	return d
