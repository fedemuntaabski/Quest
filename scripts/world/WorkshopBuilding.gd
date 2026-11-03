extends Building
class_name WorkshopBuilding

## WorkshopBuilding: Major building that yields `yield_amount` of `resource_type`
## on every production tick. ResourceManager._calculate_building_bonus() reads
## the "workshops" group, so membership is the whole integration.

@export var resource_type: String = "iron"
@export var yield_amount: int = 3


func _ready() -> void:
	super()
	add_to_group("workshops")
	building_destroyed.connect(_on_destroyed)


func configure(p_zone_id: String, p_building_type: BuildingType) -> void:
	super(p_zone_id, p_building_type)
	var cfg: Dictionary = CATALOG[building_type]
	for key: String in ["iron", "food", "lore"]:
		if int(cfg.get(key, 0)) > 0:
			resource_type = key
			yield_amount = int(cfg[key])
			break
	_notify_production()


func _on_destroyed() -> void:
	remove_from_group("workshops")
	_notify_production()


func _notify_production() -> void:
	var rm := ManagerLocator.get_resource_manager()
	if rm:
		rm.notify_production_changed()
