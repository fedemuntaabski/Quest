extends BaseAction
class_name AttackAction

var combat_component: CombatComponent

func _init(p_combat_component: CombatComponent, p_target: Node):
	combat_component = p_combat_component
	var actor_owner_local := combat_component.actor_owner if combat_component else null
	super._init(actor_owner_local, p_target)
	consume_turn = true

func can_execute() -> bool:
	print("[Action] AttackAction can_execute")
	if combat_component == null:
		return false
	return combat_component.can_attack(target)

func execute() -> void:
	print("[Action] AttackAction execute")

	if combat_component:
		var result = combat_component.attack(target)
		print("[Combat] Attack result: ", result)

	finish()