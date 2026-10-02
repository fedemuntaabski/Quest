extends Node

## GameSession (autoload, session 13): the party picked in HeroSelectMenu for the
## next run. Main2d._spawn_heroes() reads it; with no selection (scene run from
## the editor, multiplayer WaitingRoom pick) Main2d keeps its PartyConfig default.
## No class_name: the autoload name is the global identifier.

const PARTY_SIZE := 2

## Hero ids (CharacterData.character_id) in party order; empty = nothing picked.
var selected_hero_ids: Array[String] = []


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


func has_selection() -> bool:
	return not selected_hero_ids.is_empty()


func get_party_ids() -> Array[String]:
	return selected_hero_ids.duplicate()
