extends BaseAction
class_name AttackAction

var combat_component: CombatComponent
var validation_reason: String = ""
var validation_snapshot: Dictionary = {}

func _init(p_combat_component: CombatComponent, p_target: Node, p_snapshot: Dictionary = {}):
	combat_component = p_combat_component
	var actor_owner_local := combat_component.actor_owner if combat_component else null
	super._init(actor_owner_local, p_target)
	validation_snapshot = p_snapshot.duplicate(true) if p_snapshot else {}
	consume_turn = true

func can_execute() -> bool:
	if combat_component == null:
		validation_reason = "no_combat_component"
		return false
	if validation_snapshot.size() > 0 and combat_component.map_manager and combat_component.map_manager.occupancy_manager:
		var current_ver := combat_component.map_manager.occupancy_manager.get_version()
		var snap_ver := int(validation_snapshot.get("occ_version", -1))
		if snap_ver != -1 and snap_ver != current_ver:
			validation_reason = "stale_snapshot"
			return false
	validation_reason = ""
	return bool(CombatValidation.validate_target(combat_component, target, combat_component.map_manager, combat_component.attack_range, true).get("valid", false))

func execute() -> void:

	if combat_component:
		var result = combat_component.attack(target)

	finish()

func get_execution_state_token() -> Dictionary:
	var token: Dictionary = {}
	if combat_component and combat_component.actor_owner and "grid_pos" in combat_component.actor_owner:
		token["owner_cell"] = combat_component.actor_owner.grid_pos
	if target and "grid_pos" in target:
		token["target_cell"] = target.grid_pos
	if validation_snapshot.size() > 0:
		token["snapshot"] = validation_snapshot.duplicate(true)
	return token

func get_failure_reason() -> String:
	return validation_reason