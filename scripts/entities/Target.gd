class_name Target
extends RefCounted

## Target: what a TargetSelector picked. `node` is the thing to hit (null when
## the rule only names a zone: whole-graph hero hunt, HOLD).

var type: TargetRule.Type
var node: Node2D
var zone_id: String = ""
## Index of the rule that produced it (a lower one is a higher priority).
var rule_index: int = -1
## HOLD fallback: stay where it is.
var is_hold: bool = false


func _init(p_type: TargetRule.Type = TargetRule.Type.HERO_NEAREST, p_node: Node2D = null, p_zone_id: String = "", p_rule_index: int = -1) -> void:
	type = p_type
	node = p_node
	zone_id = p_zone_id
	rule_index = p_rule_index


## Still worth pursuing: a bare zone is always valid; a node must be alive/active.
func is_valid() -> bool:
	if is_hold or node == null:
		return true
	if not is_instance_valid(node):
		return false
	if node is Player:
		return (node as Player).stats.is_alive()
	if node is Nexo:
		return (node as Nexo).is_alive()
	if node is Module:
		return (node as Module).is_targetable()
	return true


func same_as(other: Target) -> bool:
	return other != null and type == other.type and node == other.node and zone_id == other.zone_id and is_hold == other.is_hold
