extends RefCounted
class_name EffectContext

var owner_actor: Node = null
var map_manager: Node = null
var card_manager: Node = null
var combat_component: CombatComponent = null
var extra: Dictionary = {}

func _init(_owner: Node = null, _map: Node = null, _card_manager: Node = null, _combat_comp: CombatComponent = null) -> void:
	owner_actor = _owner
	map_manager = _map
	card_manager = _card_manager
	combat_component = _combat_comp
