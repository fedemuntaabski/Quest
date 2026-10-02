extends Node
class_name TargetSelector

## TargetSelector: picks what an Enemy goes for from its TargetProfile (rules in
## priority order, then the fallback). Child of Enemy; Enemy keeps movement and
## attacks and asks this for the destination. Reads the revealed-only
## RoomManager graph, heroes, Nexo and modules through ManagerLocator, never
## their internals.

## A hero within this distance (px) of a retaliating enemy provokes it.
const BLOCK_RANGE := 48.0

var enemy: Enemy
var profile: TargetProfile
var _provoked_until_msec: int = 0


func setup(p_enemy: Enemy, p_profile: TargetProfile) -> void:
	enemy = p_enemy
	profile = p_profile


# ---------------- provocation ----------------

## A hero hit the enemy (Enemy._on_hurt).
func note_hit_by_hero() -> void:
	_provoked_until_msec = Time.get_ticks_msec() + int(profile.retaliate_sec * 1000.0)


## A hero standing next to a retaliating enemy counts as provoking it.
func note_blocking_hero() -> void:
	if not profile.retaliate:
		return
	for hero in ManagerLocator.get_heroes():
		if hero.stats.is_alive() and enemy.global_position.distance_to(hero.global_position) <= BLOCK_RANGE:
			note_hit_by_hero()
			return


func is_provoked() -> bool:
	return profile.retaliate and Time.get_ticks_msec() < _provoked_until_msec


## Siege-type (Nexo first), not provoked, and a Nexo to hit: ignores heroes and modules.
func is_raiding() -> bool:
	return profile.targets_nexo_first() and not is_provoked() and ManagerLocator.get_nexo() != null


# ---------------- selection ----------------

## First rule that yields a target, else the profile fallback (null = nowhere).
func select(room_manager: RoomManager) -> Target:
	var rules := TargetProfile.hunter_rules() if is_provoked() else profile.rules
	for rule in rules:
		if not _condition_ok(rule):
			continue
		var target := _evaluate(rule, room_manager)
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
	var hero := aggro_hero(room_manager) if room_manager else null
	if hero and hero.current_zone_id == goal_zone_id:
		return hero.global_position
	return Vector2.INF


func _condition_ok(rule: TargetRule) -> bool:
	if rule.condition == TargetRule.Condition.ALWAYS:
		return true
	var nexo := ManagerLocator.get_nexo()
	var carried := nexo != null and nexo.get_carrier() != null
	return carried == (rule.condition == TargetRule.Condition.NEXO_CARRIED)


func _evaluate(rule: TargetRule, room_manager: RoomManager) -> Target:
	match rule.type:
		TargetRule.Type.HERO_NEAREST:
			var reach := enemy.aggro_range if rule.aggro_range < 0.0 else rule.aggro_range
			if reach > 0.0:
				var hero := aggro_hero(room_manager, reach)
				return Target.new(rule.type, hero, hero.current_zone_id) if hero else null
			var zone := zone_of_closest_hero(room_manager)
			return Target.new(rule.type, null, zone) if zone != "" else null
		TargetRule.Type.NEXO:
			var nexo := ManagerLocator.get_nexo()
			return Target.new(rule.type, nexo, nexo.get_target_zone(room_manager)) if nexo else null
		TargetRule.Type.MODULE_ANY:
			var module_zone := find_zone_with_modules(room_manager)
			return Target.new(rule.type, null, module_zone) if module_zone != "" else null
	return null


func _fallback(room_manager: RoomManager) -> Target:
	match profile.fallback:
		TargetProfile.Fallback.NEXO:
			var nexo := ManagerLocator.get_nexo()
			return Target.new(TargetRule.Type.NEXO, nexo, nexo.get_target_zone(room_manager)) if nexo else null
		TargetProfile.Fallback.HOLD:
			var held := Target.new(TargetRule.Type.HERO_NEAREST, null, enemy.current_zone_id)
			held.is_hold = true
			return held
	var zone := zone_of_closest_hero(room_manager)
	return Target.new(TargetRule.Type.HERO_NEAREST, null, zone) if zone != "" else null


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
		if hero.current_zone_id != enemy.current_zone_id and room_manager.find_zone_path(enemy.current_zone_id, hero.current_zone_id).size() < 2:
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


func find_zone_with_modules(room_manager: RoomManager) -> String:
	for zone_id in room_manager.get_zone_ids():
		if room_manager.get_zone_kind(zone_id) != "room":
			continue
		if not room_manager.is_zone_revealed(zone_id):
			continue
		var group_id := room_manager.get_group_id(zone_id)
		if not room_manager.get_modules_in_group(group_id).is_empty():
			return zone_id
	return ""
