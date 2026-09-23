extends Module
class_name GeneratorModule

## GeneratorModule: Major module that yields `yield_amount` of `resource_type`
## on every production tick. ResourceManager._calculate_module_bonus() reads
## the "generators" group, so membership is the whole integration.

@export var resource_type: String = "industry"
@export var yield_amount: int = 3


func _ready() -> void:
	super()
	add_to_group("generators")
	module_destroyed.connect(_on_destroyed)


func configure(p_zone_id: String, p_module_type: ModuleType) -> void:
	super(p_zone_id, p_module_type)
	var cfg: Dictionary = CATALOG[module_type]
	for key: String in ["industry", "food", "science"]:
		if int(cfg.get(key, 0)) > 0:
			resource_type = key
			yield_amount = int(cfg[key])
			break


func _on_destroyed() -> void:
	remove_from_group("generators")
