class_name PrisonerSpawner
extends Node2D

## PrisonerSpawner (heroes-9): when a Prisoner room is discovered it gets a
## PrisonerCage holding one hero the party doesn't have (GameSession candidates:
## not picked, not recruited, not lost), chosen with a seeded RNG (floor seed +
## room). With no candidate or a full party (MAX_PARTY) the cell is empty and
## the HUD says so. Built by Main2d like LootSpawner.

const CAGE_OFFSET := Vector2(0, -40)
const MAX_PARTY: int = preload("res://scripts/autoload/GameSession.gd").MAX_PARTY

var cages: Dictionary = {}

var _room_manager: RoomManager
var _floor_manager: FloorManager
var _recruit: Callable


## `recruit` = Main2d.recruit_hero(hero_id, zone_id) -> Player.
func setup(room_manager: RoomManager, door_turn_system: DoorTurnSystem, floor_manager: FloorManager, recruit: Callable) -> void:
	_room_manager = room_manager
	_floor_manager = floor_manager
	_recruit = recruit
	door_turn_system.room_revealed.connect(_on_room_revealed)


func _on_room_revealed(group_id: String, _cells: Array[Vector2i]) -> void:
	for zone_id in _room_manager.get_group_zone_ids(group_id):
		if _room_manager.get_room_type(zone_id) == RoomData.RoomType.PRISONER and not cages.has(zone_id):
			spawn_for(zone_id)


## Cage for `zone_id`, or null (empty cell) when nobody can be recruited.
func spawn_for(zone_id: String) -> PrisonerCage:
	var hero_id := pick_candidate(zone_id)
	if hero_id == "":
		var hud := ManagerLocator.get_hud()
		if hud:
			hud.show_hint("Prisionero", "La celda está vacía.", QuestPalette.PARCHMENT)
		return null
	var rule := _floor_manager.config.get_room_type_rule(RoomData.RoomType.PRISONER) if _floor_manager else null
	var costs: Dictionary = rule.recruit_costs_at(_floor_manager.floor_index) if rule else {"food": 15}
	var cage := PrisonerCage.new()
	cage.name = "Cage_%s" % zone_id
	cage.setup(hero_id, zone_id, costs, _recruit)
	cage.position = _room_manager.get_center(zone_id) + CAGE_OFFSET
	add_child(cage)
	cages[zone_id] = cage
	return cage


## A hero the party could free here ("" = none, or the party is full).
func pick_candidate(zone_id: String) -> String:
	var heroes := ManagerLocator.get_heroes()
	if heroes.size() >= MAX_PARTY:
		return ""
	var party: Array[String] = []
	for hero in heroes:
		party.append(hero.stats.hero_id)
	var session := ManagerLocator.get_game_session()
	var candidates: Array[String] = session.get_recruit_candidates(party) if session else []
	for caged: PrisonerCage in cages.values():  # one hero per cage on a floor
		candidates.erase(caged.hero_id)
	if candidates.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_floor_manager.map_seed if _floor_manager else 0, zone_id, "prisoner"])
	return candidates[rng.randi_range(0, candidates.size() - 1)]
