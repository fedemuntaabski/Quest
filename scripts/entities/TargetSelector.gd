extends Node
class_name TargetSelector

## TargetSelector: picks what an Enemy goes for from its TargetProfile (rules in
## priority order, then the fallback). Child of Enemy; Enemy keeps movement and
## attacks and asks this for the destination. Reads the revealed-only
## RoomManager graph, heroes, Nexo and modules through ManagerLocator, never
## their internals.
## select()/goal_zone() are pure queries; reevaluate() stores the result in
## `current`, which makes the choice sticky (a hero already chased is kept until it
## is invalid or beyond reach * drop_range_mult) and watches it: when the target
## dies/is destroyed it re-selects at once and emits target_lost.

signal target_changed(old: Target, new: Target)
signal target_lost(old: Target)

## A hero within this distance (px) of a retaliating enemy provokes it.
const BLOCK_RANGE := 48.0

var enemy: Enemy
var profile: TargetProfile
var current: Target
var _provoked_until_msec: int = 0
var _watched: Node
var _gone_callable: Callable = _on_target_gone


func setup(p_enemy: Enemy, p_profile: TargetProfile) -> void:
	enemy = p_enemy
	profile = p_profile
	var extraction := ManagerLocator.get_extraction_manager()
	if extraction:
		extraction.phase_changed.connect(func(_new_phase: int, _old_phase: int) -> void: reevaluate(&"nexo_carried"))
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager:
		room_manager.module_built.connect(func(_zone_id: String, _module: Module) -> void: reevaluate(&"module_built"))


# ---------------- provocation ----------------

## A hero hit the enemy (Enemy._on_hurt).
func note_hit_by_hero() -> void:
	_provoked_until_msec = Enemy.game_msec() + int(profile.retaliate_sec * 1000.0)


## A hero standing next to a retaliating enemy counts as provoking it.
func note_blocking_hero() -> void:
	if not profile.retaliate:
		return
	for hero in ManagerLocator.get_heroes():
		if hero.stats.is_alive() and enemy.global_position.distance_to(hero.global_position) <= BLOCK_RANGE:
			note_hit_by_hero()
			return


func is_provoked() -> bool:
	return profile.retaliate and Enemy.game_msec() < _provoked_until_msec


## Siege-type (Nexo first), not provoked, and a Nexo to hit: ignores heroes and modules.
func is_raiding() -> bool:
	return profile.targets_nexo_first() and not is_provoked() and ManagerLocator.get_nexo() != null


# ---------------- selection ----------------

## Stores select() in `current` (emitting target_changed) and returns it.
func reevaluate(_reason: StringName = &"tick") -> Target:
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager == null or enemy == null or not enemy.is_alive():
		return current
	_set_current(select(room_manager))
	return current


## First rule that yields a target, else the profile fallback (null = nowhere).
func select(room_manager: RoomManager) -> Target:
	var rules := TargetProfile.hunter_rules() if is_provoked() else profile.rules
	for i in rules.size():
		if not _condition_ok(rules[i]):
			continue
		var target := _evaluate(rules[i], i, room_manager)
		if target != null:
			return target
	return _fallback(room_manager)


## Zone this enemy heads for right now ("" = nowhere).
func goal_zone(room_manager: RoomManager) -> String:
	var target := select(room_manager)
	return target.zone_id if target else ""


## Exact spot to close in on inside the goal zone (Vector2.INF = zone center).
func goal_point(goal_zone_id: String) -> Vector2:
	if is_raiding():
		return ManagerLocator.get_nexo().get_target_position()
	var room_manager := ManagerLocator.get_room_manager()
	if room_manager == null:
		return Vector2.INF
	var target := current if current != null and current.zone_id == goal_zone_id and current.is_valid() else select(room_manager)
	if target and target.node is Player and (target.node as Player).current_zone_id == goal_zone_id:
		return target.node.global_position
	var hero := aggro_hero(room_manager)
	if hero and hero.current_zone_id == goal_zone_id:
		return hero.global_position
	return Vector2.INF


func _condition_ok(rule: TargetRule) -> bool:
	if rule.condition == TargetRule.Condition.ALWAYS:
		return true
	var nexo := ManagerLocator.get_nexo()
	var carried := nexo != null and nexo.get_carrier() != null
	return carried == (rule.condition == TargetRule.Condition.NEXO_CARRIED)


func _evaluate(rule: TargetRule, index: int, room_manager: RoomManager) -> Target:
	var reach := enemy.aggro_range if rule.aggro_range < 0.0 else rule.aggro_range
	match rule.type:
		TargetRule.Type.HERO_NEAREST:
			if reach > 0.0:
				var kept := _keep_current(index, reach, room_manager)
				var hero := kept if kept else aggro_hero(room_manager, reach)
				return Target.new(rule.type, hero, hero.current_zone_id, index) if hero else null
			var zone := zone_of_closest_hero(room_manager)
			return Target.new(rule.type, null, zone, index) if zone != "" else null
		TargetRule.Type.HERO_WEAKEST:
			var kept_hero := _keep_current(index, reach, room_manager) if reach > 0.0 else null
			var weakest := kept_hero if kept_hero else _weakest_hero(room_manager, reach)
			return Target.new(rule.type, weakest, weakest.current_zone_id, index) if weakest else null
		TargetRule.Type.HERO_CARRIER:
			var nexo := ManagerLocator.get_nexo()
			var carrier := nexo.get_carrier() if nexo else null
			if carrier and carrier.stats.is_alive() and _reachable(room_manager, carrier):
				return Target.new(rule.type, carrier, carrier.current_zone_id, index)
			return null
		TargetRule.Type.NEXO:
			var target_nexo := ManagerLocator.get_nexo()
			return Target.new(rule.type, target_nexo, target_nexo.get_target_zone(room_manager), index) if target_nexo else null
		_:
			return _nearest_module(rule.type, index, room_manager)


func _fallback(room_manager: RoomManager) -> Target:
	var rule_count := profile.rules.size()
	match profile.fallback:
		TargetProfile.Fallback.NEXO:
			var nexo := ManagerLocator.get_nexo()
			return Target.new(TargetRule.Type.NEXO, nexo, nexo.get_target_zone(room_manager), rule_count) if nexo else null
		TargetProfile.Fallback.HOLD:
			var held := Target.new(TargetRule.Type.HERO_NEAREST, null, enemy.current_zone_id, rule_count)
			held.is_hold = true
			return held
	var zone := zone_of_closest_hero(room_manager)
	return Target.new(TargetRule.Type.HERO_NEAREST, null, zone, rule_count) if zone != "" else null


# ---------------- candidates ----------------

## Closest living hero within `reach` px (default: the enemy's aggro_range) that
## is reachable over the revealed graph.
func aggro_hero(room_manager: RoomManager, reach: float = -1.0) -> Player:
	var best: Player = null
	var best_dist := enemy.aggro_range if reach < 0.0 else reach
	for hero in ManagerLocator.get_heroes():
		if not hero.stats.is_alive():
			continue
		var dist := enemy.global_position.distance_to(hero.global_position)
		if dist > best_dist:
			continue
		if not _reachable(room_manager, hero):
			continue
		best = hero
		best_dist = dist
	return best


## Zone of the closest hero (fewest zones over the revealed graph), so the
## hero selection never redirects enemies. "" if none is reachable.
func zone_of_closest_hero(room_manager: RoomManager) -> String:
	var best := ""
	var best_len := 0
	for hero in ManagerLocator.get_heroes():
		if hero.current_zone_id == enemy.current_zone_id:
			return enemy.current_zone_id
		var path_len := room_manager.find_zone_path(enemy.current_zone_id, hero.current_zone_id).size()
		if path_len > 0 and (best == "" or path_len < best_len):
			best = hero.current_zone_id
			best_len = path_len
	return best


## Living hero with the least HP within `reach` px (0 = anywhere reachable); ties: nearest.
func _weakest_hero(room_manager: RoomManager, reach: float) -> Player:
	var best: Player = null
	for hero in ManagerLocator.get_heroes():
		if not hero.stats.is_alive() or not _reachable(room_manager, hero):
			continue
		var dist := enemy.global_position.distance_to(hero.global_position)
		if reach > 0.0 and dist > reach:
			continue
		if best == null or hero.stats.current_hp < best.stats.current_hp \
				or (hero.stats.current_hp == best.stats.current_hp and dist < enemy.global_position.distance_to(best.global_position)):
			best = hero
	return best


func _reachable(room_manager: RoomManager, hero: Player) -> bool:
	return hero.current_zone_id == enemy.current_zone_id or room_manager.find_zone_path(enemy.current_zone_id, hero.current_zone_id).size() >= 2


## The hero already chased by the same rule, while it is valid and within the
## drop distance (reach * drop_range_mult): no flip-flopping between heroes.
func _keep_current(index: int, reach: float, room_manager: RoomManager) -> Player:
	if current == null or current.rule_index != index or not (current.node is Player) or not current.is_valid():
		return null
	var hero := current.node as Player
	if enemy.global_position.distance_to(hero.global_position) <= reach * profile.drop_range_mult and _reachable(room_manager, hero):
		return hero
	return null


func _module_matches(type: TargetRule.Type, module: Module) -> bool:
	if not module.is_targetable():
		return false
	match type:
		TargetRule.Type.MODULE_GENERATOR:
			return module is GeneratorModule
		TargetRule.Type.MODULE_TURRET:
			return module is TurretModule
		TargetRule.Type.MODULE_TRAP:
			return module.is_trap()
	return true


## Nearest (fewest zones, then distance) targetable module of `type` in a revealed
## room reachable from here. Switched-off modules count.
func _nearest_module(type: TargetRule.Type, index: int, room_manager: RoomManager) -> Target:
	var best: Module = null
	var best_zone := ""
	var best_len := 0
	var best_dist := 0.0
	for zone_id in room_manager.get_zone_ids():
		if room_manager.get_zone_kind(zone_id) != "room" or not room_manager.is_zone_revealed(zone_id):
			continue
		var path_len := room_manager.find_zone_path(enemy.current_zone_id, zone_id).size()
		if path_len == 0:
			continue
		for module in room_manager.get_modules_in_group(room_manager.get_group_id(zone_id)):
			if not _module_matches(type, module):
				continue
			var dist := enemy.global_position.distance_to(module.get_target_position())
			if best == null or path_len < best_len or (path_len == best_len and dist < best_dist):
				best = module
				best_zone = zone_id
				best_len = path_len
				best_dist = dist
	return Target.new(type, best, best_zone, index) if best else null


## The module to hit on arriving in `room`: the one it is already after, else the
## first its module rules accept, else (hits_modules_en_route) any targetable one.
func pick_module_in_room(room: RoomZone) -> Module:
	if room == null:
		return null
	var modules: Array[Module] = []
	for module in room.get_modules():
		if is_instance_valid(module) and module.is_targetable():
			modules.append(module)
	if current and current.node in modules:
		return current.node as Module
	for rule in profile.rules:
		if rule.is_module_rule():
			for module in modules:
				if _module_matches(rule.type, module):
					return module
	return modules[0] if profile.hits_modules_en_route and not modules.is_empty() else null


# ---------------- tracking ----------------

func _set_current(next: Target) -> void:
	if next == null and current == null:
		return
	if next != null and next.same_as(current):
		current = next  # same thing, refreshed rule index
		return
	var old := current
	current = next
	_watch(next.node if next else null)
	target_changed.emit(old, next)


## Watch the one thing whose death makes the target moot.
func _watch(node: Node) -> void:
	if _watched == node:
		return
	if is_instance_valid(_watched):
		var old_signal := _death_signal(_watched)
		if old_signal.is_connected(_gone_callable):
			old_signal.disconnect(_gone_callable)
	_watched = node
	if node != null:
		var new_signal := _death_signal(node)
		if not new_signal.is_connected(_gone_callable):
			new_signal.connect(_gone_callable)


func _death_signal(node: Node) -> Signal:
	if node is Module:
		return (node as Module).module_destroyed
	if node is Player:
		return (node as Player).stats.died
	return (node as Nexo).destroyed


func _on_target_gone() -> void:
	var old := current
	current = null
	_watched = null
	target_lost.emit(old)
	reevaluate(&"lost")
