extends Resource
class_name TargetRule

## TargetRule: one priority of a TargetProfile — "go for this kind of target,
## if it is available". TargetSelector evaluates the profile's rules in order
## and the first one that yields a target wins.

enum Type {
	HERO_NEAREST,
	HERO_WEAKEST,
	HERO_CARRIER,
	NEXO,
	MODULE_GENERATOR,
	MODULE_TURRET,
	MODULE_TRAP,
	MODULE_ANY,
}
enum Condition { ALWAYS, NEXO_CARRIED, NEXO_IDLE }

@export var type: Type = Type.HERO_NEAREST
## Hero rules: heroes closer than this (px) count. 0 = any hero reachable over
## the revealed graph; < 0 = the enemy's own EnemyType.aggro_range.
@export var aggro_range: float = 0.0
@export var condition: Condition = Condition.ALWAYS
## 0 = EnemyType.attack_range.
@export var attack_range: float = 0.0


static func make(p_type: Type, p_aggro_range: float = 0.0, p_condition: Condition = Condition.ALWAYS) -> TargetRule:
	var rule := TargetRule.new()
	rule.type = p_type
	rule.aggro_range = p_aggro_range
	rule.condition = p_condition
	return rule


func is_hero_rule() -> bool:
	return type in [Type.HERO_NEAREST, Type.HERO_WEAKEST, Type.HERO_CARRIER]


func is_module_rule() -> bool:
	return type in [Type.MODULE_GENERATOR, Type.MODULE_TURRET, Type.MODULE_TRAP, Type.MODULE_ANY]
