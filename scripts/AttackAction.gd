extends BaseAction
class_name AttackAction

var attacker: CombatComponent = null
var target_actor: Node = null
var result: Dictionary = {}

func _init(p_attacker: CombatComponent = null, p_target: Node = null) -> void:
	super(p_attacker, p_target)
	attacker = p_attacker
	target_actor = p_target

func can_execute() -> bool:
	if attacker == null:
		consume_turn = false
		return false

	if not attacker.can_attack(target_actor):
		consume_turn = false
		return false

	return true

func execute() -> void:
	if attacker == null:
		consume_turn = false
		finish()
		return

	if not attacker.can_attack(target_actor):
		consume_turn = false
		finish()
		return

	result = attacker.attack(target_actor)
	finish()
