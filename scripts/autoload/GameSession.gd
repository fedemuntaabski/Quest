extends Node

## GameSession (autoload, session 13): the party picked in HeroSelectMenu for the
## next run. Main2d._spawn_heroes() reads it; with no selection (scene run from
## the editor, multiplayer WaitingRoom pick) Main2d keeps its PartyConfig default.
## No class_name: the autoload name is the global identifier.

## Heroes picked in HeroSelectMenu at the start of a run.
const PARTY_SIZE := 2
## heroes-9: party cap with recruits (Prisoner rooms).
const MAX_PARTY := 4

## Hero ids (CharacterData.character_id) in party order; empty = nothing picked.
var selected_hero_ids: Array[String] = []
## Run state (heroes-9), reset by reset_run() in Main._begin_new_run:
## heroes freed from a Prisoner room (join the party on every next floor) and
## heroes lost for good (downed and not revived before the floor ended).
var recruited_ids: Array[String] = []
var lost_ids: Array[String] = []
## progresion-10: DifficultyLevel.id picked in HeroSelectMenu (kept between runs).
var difficulty: String = "normal"
## progresion-10: this run's summary numbers (RunSummary, SaveManager.record_run).
## Reset by reset_run(); filled by EnemyManager (kills), PartyInventory
## (item_acquired), BestiaryService (entry_unlocked), FloorManager (floors) and
## Main2d (time, only while the run is ACTIVE).
var run_stats: Dictionary = new_run_stats()


func _ready() -> void:
	_connect_run_sources.call_deferred()  # BestiaryService loads after this autoload


func _connect_run_sources() -> void:
	var inventory := get_node_or_null("/root/PartyInventory")
	if inventory:
		inventory.item_acquired.connect(func(_item: ItemData) -> void: add_stat("items"))
	var bestiary := get_node_or_null("/root/BestiaryService")
	if bestiary:
		bestiary.entry_unlocked.connect(_on_bestiary_unlocked)


## Stores the pick if it is exactly PARTY_SIZE distinct, known heroes.
func set_selection(ids: Array[String]) -> bool:
	if ids.size() != PARTY_SIZE:
		return false
	var known: Array[String] = []
	for data in CharacterDatabase.get_all():
		known.append(data.character_id)
	for i in ids.size():
		if not known.has(ids[i]) or ids.find(ids[i]) != i:
			return false
	selected_hero_ids = ids.duplicate()
	return true


func clear() -> void:
	selected_hero_ids.clear()
	reset_run()


func reset_run() -> void:
	recruited_ids.clear()
	lost_ids.clear()
	run_stats = new_run_stats()


func new_run_stats() -> Dictionary:
	return {"elapsed_sec": 0.0, "floor_reached": 1, "floors_cleared": 0, "kills": 0, "items": 0,
		"bestiary_new": 0, "difficulty": difficulty, "victory": false}


func add_stat(key: String, amount: Variant = 1) -> void:
	run_stats[key] = run_stats.get(key, 0) + amount


## A new bestiary entry (first sighting) counts as a new record of this run.
func _on_bestiary_unlocked(_enemy_id: String, tier: int) -> void:
	if tier == 1:  # BestiaryEntry.Tier.SEEN
		add_stat("bestiary_new")


## The floor's party: `base_ids` (the pick, or Main2d's fallback) + recruits,
## minus the lost, capped at MAX_PARTY.
func resolve_party(base_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id in base_ids + recruited_ids:
		if not lost_ids.has(id) and not out.has(id) and out.size() < MAX_PARTY:
			out.append(id)
	return out


## Heroes a Prisoner room can hold: known, not in `party_ids`, not lost.
func get_recruit_candidates(party_ids: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for data in CharacterDatabase.get_all():
		var id := data.character_id
		if not party_ids.has(id) and not lost_ids.has(id) and not recruited_ids.has(id):
			out.append(id)
	return out


func add_recruit(id: String) -> void:
	if not recruited_ids.has(id):
		recruited_ids.append(id)
	lost_ids.erase(id)


func mark_lost(id: String) -> void:
	if not lost_ids.has(id):
		lost_ids.append(id)


func has_selection() -> bool:
	return not selected_hero_ids.is_empty()


func get_party_ids() -> Array[String]:
	return selected_hero_ids.duplicate()
