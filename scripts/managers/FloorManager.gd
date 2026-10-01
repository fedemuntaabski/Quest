extends Node
class_name FloorManager

## FloorManager: per-floor facade over FloorConfig. Scene-instantiated per
## Main2d (group "floor_manager"), like EnemyManager/ExtractionManager — so it
## does NOT own the run's floor counter: that survives Main2d reloads on the
## Main orchestrator (Main.current_floor), which passes it in via setup().
## Systems read their scaled numbers from here; nothing else touches FloorConfig.

signal floor_completed(floor_index: int)

const DEFAULT_CONFIG: FloorConfig = preload("res://resources/floors/default_floor_config.tres")
## Discovery banner: above the room center (reward text floats at the center).
const BANNER_OFFSET := Vector2(0, -56)
const BANNER_INTENSITY := 1.5
const DESCRIPTION_OFFSET := Vector2(0, -32)

@export var config: FloorConfig = DEFAULT_CONFIG

var floor_index: int = 1
## Deterministic MapGenerator seed for this floor (run seed + floor index).
var map_seed: int = 0
## Set by Main2d; read by on_room_discovered (room types, loop groups).
## Null = no map info: every discovery pays plain dust (as before session 11).
var room_manager: RoomManager
var _completed: bool = false
## Types whose long hint was already shown this run (survives floors).
static var _seen_types: Dictionary = {}


func _ready() -> void:
	add_to_group("floor_manager")


func setup(p_floor_index: int, run_seed: int = 0) -> void:
	floor_index = maxi(p_floor_index, 1)
	map_seed = hash([run_seed, floor_index])
	if floor_index > 1 and config.dust_bonus_on_descend > 0:
		var resource_manager := ManagerLocator.get_resource_manager()
		if resource_manager:
			resource_manager.add_resource("dust", config.dust_bonus_on_descend)
	QuestLogger.info(QuestLogger.Category.MAP, "Floor %d/%d started (enemy HP x%.2f, dmg x%.2f)." % [floor_index, config.max_floors, enemy_hp_multiplier(), enemy_damage_multiplier()])


## Called once when this floor's exit is reached (ExtractionManager.victory_declared).
func complete_floor() -> void:
	if _completed:
		return
	_completed = true
	QuestLogger.info(QuestLogger.Category.MAP, "Floor %d completed." % floor_index)
	floor_completed.emit(floor_index)


## DoorTurnSystem.room_revealed listener: every discovered room pays dust,
## regardless of invasions. Amount scales per floor (FloorConfig "Discovery").
## Fires once per group, so room-type rewards/heals are one-time. A loop
## corridor group (group id = corridor zone id) discovers no room: nothing.
func on_room_discovered(room_id: String, _cells: Array[Vector2i]) -> void:
	var resource_manager := ManagerLocator.get_resource_manager()
	if resource_manager == null:
		return
	if room_manager and room_manager.get_zone_kind(room_id) == "corridor":
		return
	var amount := config.discovery_dust(floor_index) + roundi(resource_manager.get_bonus(ResearchEntry.Effect.DISCOVERY_DUST))
	if amount > 0:
		resource_manager.add_resource("dust", amount)
		QuestLogger.info(QuestLogger.Category.MAP, "Discovered '%s': +%d dust." % [room_id, amount])
	if room_manager:
		_show_room_banner(room_id)
		_apply_room_type_discovery(room_id, resource_manager)


static func reset_seen_types() -> void:
	_seen_types.clear()


## Brief floating name + one-line effect of a special room, once, when it is
## discovered (RoomTypeVisual.banner_text/description), above the reward text so
## they don't overlap. The first time a type shows up its long hint opens on the HUD.
func _show_room_banner(room_id: String) -> void:
	var type := room_manager.get_room_type(room_id)
	var visual := room_manager.visual_config.room_type_visual(type)
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if visual == null or visual.banner_text == "" or text_mgr == null:
		return
	var center := room_manager.get_center(room_id)
	text_mgr.spawn_text(center + BANNER_OFFSET, visual.banner_text, visual.color, true, BANNER_INTENSITY)
	if visual.description != "":
		text_mgr.spawn_text(center + DESCRIPTION_OFFSET, visual.description, visual.color)
	if visual.hint != "" and not _seen_types.has(type) and not get_tree().get_nodes_in_group("hud").is_empty():
		_seen_types[type] = true
		get_tree().call_group("hud", "show_hint", visual.display_name, visual.hint, visual.color)


func _apply_room_type_discovery(room_id: String, resource_manager: ResourceManager) -> void:
	var type := room_manager.get_room_type(room_id)
	var rule := config.get_room_type_rule(type)
	if rule == null:
		return
	var visual := room_manager.visual_config.room_type_visual(type)
	var name_of_type := visual.display_name if visual else ""
	var reward := rule.reward_at(floor_index)
	if reward > 0 and rule.reward_resource != "":
		resource_manager.add_resource(rule.reward_resource, reward)
		var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
		if text_mgr:
			text_mgr.spawn_text(room_manager.get_center(room_id), "%s: +%d %s" % [name_of_type, reward, Module.RESOURCE_LABELS.get(rule.reward_resource, rule.reward_resource)], room_manager.visual_config.room_type_color(type))
		QuestLogger.info(QuestLogger.Category.MAP, "Room type reward in '%s': +%d %s." % [room_id, reward, rule.reward_resource])
	var player_stats := ManagerLocator.get_player_stats()
	if rule.heal_on_discovery > 0 and player_stats:
		for hero_stats in player_stats.get_all_stats():
			if hero_stats.is_alive():
				hero_stats.heal(rule.heal_on_discovery)


## RoomTypeRule for `type` on this run's config (null for Combat/Start/Exit).
func room_type_rule(type: RoomData.RoomType) -> RoomTypeRule:
	return config.get_room_type_rule(type)


## Weighted EnemyType from this floor's pool (null = no pool configured).
## `role` (EnemyType.Role, -1 = any) restricts it; no type of that role = any type.
func roll_enemy_type(role: int = -1, rng: RandomNumberGenerator = null) -> EnemyType:
	var pool := config.enemy_pool(floor_index)
	if pool == null:
		return null
	var type := pool.roll(rng, role) if role >= 0 else null
	return type if type else pool.roll(rng)


func raider_ratio() -> float:
	return config.raider_ratio(floor_index)


## Role of the next spawn: RAIDER with probability raider_ratio().
func roll_role(rng: RandomNumberGenerator = null) -> EnemyType.Role:
	var roll := rng.randf() if rng else randf()
	return EnemyType.Role.RAIDER if roll < raider_ratio() else EnemyType.Role.HUNTER


func room_count() -> int:
	return config.room_count(floor_index)


func branch_chance() -> float:
	return config.branch_chance(floor_index)


func is_final_floor() -> bool:
	return floor_index >= config.max_floors


func enemy_hp_multiplier() -> float:
	return config.enemy_hp_multiplier(floor_index)


func enemy_damage_multiplier() -> float:
	return config.enemy_damage_multiplier(floor_index)


func invasion_chance_bonus() -> float:
	return config.invasion_chance_bonus(floor_index)


func extra_invasion_enemies() -> int:
	return config.extra_invasion_enemies(floor_index)


func extraction_interval() -> float:
	return config.extraction_interval(floor_index)
