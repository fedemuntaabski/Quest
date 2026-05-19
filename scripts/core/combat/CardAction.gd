extends BaseAction
class_name CardAction

var card_system: CombatCardSystem
var card_data: CardData

func _init(p_system: CombatCardSystem, p_card: CardData, p_target: Node) -> void:
	card_system = p_system
	card_data = p_card
	var actor_owner_local := card_system.owner_actor if card_system else null
	super._init(actor_owner_local, p_target)
	consume_turn = true

func can_execute() -> bool:
	if card_system == null:
		print("[CardAction] can_execute: reject reason=no_card_system card=%s target=%s" % [card_data.display_name if card_data else "NULL", target.name if target else "NULL"])
		return false
	if card_data == null:
		print("[CardAction] can_execute: reject reason=no_card_data target=%s" % [target.name if target else "NULL"])
		return false
	if target == null:
		print("[CardAction] can_execute: reject reason=no_target card=%s" % [card_data.display_name])
		return false
	var ok := card_system.can_play(card_data, target)
	if not ok:
		print("[CardAction] can_execute: reject reason=can_play_false card=%s target=%s" % [card_data.display_name, target.name if target else "NULL"])
	return ok

func execute() -> void:
	print("[CardAction] execute: START card=%s, target=%s" % [card_data.display_name if card_data else "NULL", target.name if target else "NULL"])
	if card_system:
		print("[CardAction] execute: awaiting card_system.execute_card()")
		await card_system.execute_card(card_data, target)
		print("[CardAction] execute: card_system.execute_card() completed")
	else:
		print("[CardAction] execute: card_system is NULL")
	print("[CardAction] execute: calling finish()")
	finish()
	print("[CardAction] execute: COMPLETE")
