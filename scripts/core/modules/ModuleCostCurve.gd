extends Resource
class_name ModuleCostCurve

## Single place for module prices: each module of a type already built makes the
## next one dearer; demolishing refunds a share; repairs scale with missing HP.

const DEFAULT_PATH := "res://resources/modules/module_cost_curve.tres"

## Extra share of base_cost per module of that type already built.
@export var step: float = 0.5
@export var refund_pct: float = 0.5
## Full repair (0 -> max HP) costs base_cost * repair_pct.
@export var repair_pct: float = 0.5

static var _default: ModuleCostCurve


static func get_default() -> ModuleCostCurve:
	if _default == null:
		_default = load(DEFAULT_PATH) as ModuleCostCurve
	return _default


func cost(base_cost: int, built_count: int) -> int:
	return base_cost + roundi(base_cost * step * built_count)


func refund(paid_cost: int) -> int:
	return roundi(paid_cost * refund_pct)


func repair_cost(base_cost: int, missing_hp: int, max_hp: int) -> int:
	if missing_hp <= 0:
		return 0
	return maxi(1, roundi(base_cost * repair_pct * float(missing_hp) / float(maxi(max_hp, 1))))
