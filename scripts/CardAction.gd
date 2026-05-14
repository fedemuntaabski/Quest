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
	return card_system != null and card_system.can_play(card_data, target)

func execute() -> void:
	if card_system:
		await card_system.execute_card(card_data, target)
	finish()
