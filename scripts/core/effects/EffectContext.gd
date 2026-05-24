extends RefCounted
class_name EffectContext

var owner_actor: Node = null
var map_manager: Node = null
var card_manager: Node = null
var combat_component: CombatComponent = null
var extra: Dictionary = {}
var _started: bool = false
var _committed: bool = false
var _rolled_back: bool = false
var _rollback_ops: Array = [] # array of {callable: Callable, args: Array}

# EffectContext: transactional context used by EffectApplier to
# register rollback operations when applying multi-step effects.
# - `begin()` must be called before registering rollback ops.
# - `commit()` clears rollback ops on success; `rollback()` runs them in
#   reverse order on failure.

func _init(_owner: Node = null, _map: Node = null, _card_manager: Node = null, _combat_comp: CombatComponent = null) -> void:
	owner_actor = _owner
	map_manager = _map
	card_manager = _card_manager
	combat_component = _combat_comp

func begin() -> void:
	# Start a new effect transaction
	_started = true
	_committed = false
	_rolled_back = false
	_rollback_ops.clear()

func register_rollback(callable: Callable, args: Array = []) -> void:
	if callable == null:
		return
	_rollback_ops.append({"callable": callable, "args": args})

func commit() -> void:
	if not _started or _rolled_back:
		return
	_committed = true
	_rollback_ops.clear()

func rollback() -> void:
	if not _started or _committed or _rolled_back:
		return
	# Execute rollback operations in reverse order
	for i in range(_rollback_ops.size() - 1, -1, -1):
		var entry: Dictionary = _rollback_ops[i]
		var cb: Callable = entry.get("callable") as Callable
		var args: Array = entry.get("args", []) as Array
		if cb != null:
			# Use callv to pass array of args
			cb.callv(args)
	_rolled_back = true
	_rollback_ops.clear()
