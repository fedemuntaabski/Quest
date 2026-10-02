extends Node

## SelectionManager (autoload, session 14): the ONE source of truth for which
## heroes are selected and for the control groups (1..GROUP_COUNT). Everything
## else asks here (PlayerStats.active_hero_id is a view of the primary hero).
## Ids are CharacterData.character_id (= CharacterStats.hero_id). No class_name:
## the autoload name is the global identifier.

## Selection changed (also when only the order/primary changed).
signal selection_changed(selected_ids: Array[String])
signal groups_changed

const GROUP_COUNT := 3

## Selection order; the first one is the primary hero (camera, sheet, level API).
var selected_ids: Array[String] = []
## group number → Array[String] of hero ids. Survives floors (this autoload
## outlives Main2d); reset() clears it for a new run.
var groups: Dictionary = {}


func get_primary_id() -> String:
	return selected_ids[0] if not selected_ids.is_empty() else ""


func get_selected_ids() -> Array[String]:
	return selected_ids.duplicate()


func is_selected(hero_id: String) -> bool:
	return selected_ids.has(hero_id)


## Click / F1: only this hero. false if it is not a live registered hero.
func select_only(hero_id: String) -> bool:
	if not _is_live(hero_id):
		return false
	var ids: Array[String] = [hero_id]
	return set_selection(ids)


## True if this hero is the whole selection.
func is_only(hero_id: String) -> bool:
	return selected_ids.size() == 1 and selected_ids[0] == hero_id


## Ctrl+click / Ctrl+F1: add or remove. The last selected hero can't be removed
## (there is always a hero to order around). false if nothing changed.
func toggle(hero_id: String) -> bool:
	if not _is_live(hero_id):
		return false
	var next := selected_ids.duplicate()
	if next.has(hero_id):
		if next.size() == 1:
			return false
		next.erase(hero_id)
	else:
		next.append(hero_id)
	return set_selection(next)


## Live heroes of `ids`, de-duplicated, in order. false (and no change) if none is live.
func set_selection(ids: Array[String]) -> bool:
	var next: Array[String] = []
	for id in ids:
		if _is_live(id) and not next.has(id):
			next.append(id)
	if next.is_empty():
		return false
	if next != selected_ids:
		selected_ids = next
		selection_changed.emit(get_selected_ids())
	return true


## Ctrl+N: the current selection becomes group N.
func assign_group(n: int) -> bool:
	if n < 1 or n > GROUP_COUNT or selected_ids.is_empty():
		return false
	groups[n] = selected_ids.duplicate()
	groups_changed.emit()
	return true


## N: select the live members of group N. false if the group is empty/unset.
func select_group(n: int) -> bool:
	return set_selection(get_group(n, true))


## Members of group N; `live_only` drops heroes that are not registered/alive.
func get_group(n: int, live_only: bool = false) -> Array[String]:
	var out: Array[String] = []
	for id in groups.get(n, []):
		if not live_only or _is_live(id):
			out.append(id)
	return out


## Group numbers a hero belongs to, ascending.
func group_of(hero_id: String) -> Array[int]:
	var out: Array[int] = []
	for n in range(1, GROUP_COUNT + 1):
		if groups.get(n, []).has(hero_id):
			out.append(n)
	return out


## Dead/gone hero: out of the selection and every group. If that empties the
## selection, another live hero takes over.
func remove_hero(hero_id: String) -> void:
	var changed_groups := false
	for n: int in groups.keys():
		if groups[n].has(hero_id):
			groups[n].erase(hero_id)
			changed_groups = true
	if changed_groups:
		groups_changed.emit()
	if not selected_ids.has(hero_id):
		return
	selected_ids.erase(hero_id)
	if selected_ids.is_empty():
		var ps := ManagerLocator.get_player_stats()
		for id in (ps.get_hero_ids() if ps else []):
			if id != hero_id and _is_live(id):
				selected_ids.append(id)
				break
	selection_changed.emit(get_selected_ids())


## Main2d, after spawning a floor's party: keep the previous selection where the
## hero still exists (groups are untouched), else select the first hero.
func on_party_spawned(party_ids: Array[String]) -> void:
	var next: Array[String] = []
	for id in selected_ids:
		if party_ids.has(id) and _is_live(id):
			next.append(id)
	if next.is_empty() and not party_ids.is_empty():
		next.append(party_ids[0])
	if next != selected_ids:
		selected_ids = next
	selection_changed.emit(get_selected_ids())


## New run: nobody selected, no groups.
func reset() -> void:
	selected_ids.clear()
	groups.clear()
	selection_changed.emit(get_selected_ids())
	groups_changed.emit()


func _is_live(hero_id: String) -> bool:
	if hero_id == "":
		return false
	var ps := ManagerLocator.get_player_stats()
	var stats: CharacterStats = ps.get_hero_stats(hero_id) if ps else null
	return stats != null and stats.is_alive()
