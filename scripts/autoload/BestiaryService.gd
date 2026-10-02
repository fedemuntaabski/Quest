extends Node

## BestiaryService — Autoload. What the player has seen/killed, per save slot.
## Not run state: Main._begin_new_run() never touches it. SaveManager calls
## write_to()/read_from() (section [bestiary] of user://slot_N.cfg) and reset();
## it saves (deferred, debounced) after every change once a slot is loaded.
## Autoload code in --script runs without autoload identifiers: ManagerLocator only.

signal entry_updated(enemy_id: String)
## An entry reached a higher tier (first sight, first kill, mastery).
signal entry_unlocked(enemy_id: String, tier: BestiaryEntry.Tier)

const SECTION := "bestiary"
const VERSION := 1
const ENEMIES_DIR := "res://resources/enemies"

var entries: Dictionary = {}
## Slot these entries belong to (0 = none loaded yet): SaveManager only writes
## the section into that slot's file.
var slot: int = 0

var _types: Array[EnemyType] = []
var _flush_queued: bool = false


## Every EnemyType in resources/enemies, by bestiary_order then name.
func get_all_ordered() -> Array[EnemyType]:
	if _types.is_empty():
		for file in DirAccess.get_files_at(ENEMIES_DIR):
			var path := "%s/%s" % [ENEMIES_DIR, file.trim_suffix(".remap")]
			if path.ends_with(".tres"):
				var type := load(path) as EnemyType
				if type:
					_types.append(type)
		_types.sort_custom(func(a: EnemyType, b: EnemyType) -> bool:
			return a.bestiary_order < b.bestiary_order or (a.bestiary_order == b.bestiary_order and a.display_name < b.display_name))
	return _types


func get_type(enemy_id: String) -> EnemyType:
	for type in get_all_ordered():
		if type.id == enemy_id:
			return type
	return null


## Never null: an unknown id is an UNKNOWN entry.
func get_entry(enemy_id: String) -> BestiaryEntry:
	if entries.has(enemy_id):
		return entries[enemy_id]
	return BestiaryEntry.new(enemy_id)


func get_tier(enemy_id: String) -> BestiaryEntry.Tier:
	return get_entry(enemy_id).tier()


func unlocked_count() -> int:
	var count := 0
	for type in get_all_ordered():
		if get_tier(type.id) != BestiaryEntry.Tier.UNKNOWN:
			count += 1
	return count


## First spawn of a type counts as "seen" (spawns are always in revealed rooms).
func register_seen(type: EnemyType, floor_index: int) -> void:
	if type == null or type.id == "":
		return
	var entry := _entry_for_write(type.id)
	var before := entry.tier()
	entry.seen_count += 1
	if entry.first_seen_floor == 0:
		entry.first_seen_floor = floor_index
	entry.max_floor_seen = maxi(entry.max_floor_seen, floor_index)
	_after_change(entry, before)


## Only for deaths caused by damage (Enemy.killed_by_damage), never for a node freed by a floor change.
func register_kill(type: EnemyType, floor_index: int) -> void:
	if type == null or type.id == "":
		return
	var entry := _entry_for_write(type.id)
	var before := entry.tier()
	entry.kill_count += 1
	if entry.first_kill_floor == 0:
		entry.first_kill_floor = floor_index
	entry.seen_count = maxi(entry.seen_count, 1)
	entry.first_seen_floor = entry.first_seen_floor if entry.first_seen_floor > 0 else floor_index
	entry.max_floor_seen = maxi(entry.max_floor_seen, floor_index)
	_after_change(entry, before)


func reset() -> void:
	entries.clear()
	slot = 0


func write_to(cfg: ConfigFile) -> void:
	cfg.set_value(SECTION, "version", VERSION)
	for id: String in entries:
		cfg.set_value(SECTION, id, (entries[id] as BestiaryEntry).to_dict())


## Replaces the entries with the file's. Ids that no longer exist are ignored.
func read_from(cfg: ConfigFile) -> void:
	entries.clear()
	if not cfg.has_section(SECTION):
		return
	for id in cfg.get_section_keys(SECTION):
		var raw: Variant = cfg.get_value(SECTION, id)
		if id == "version" or not raw is Dictionary or get_type(id) == null:
			continue
		entries[id] = BestiaryEntry.from_dict(id, raw)


func _entry_for_write(enemy_id: String) -> BestiaryEntry:
	if not entries.has(enemy_id):
		entries[enemy_id] = BestiaryEntry.new(enemy_id)
	return entries[enemy_id]


func _after_change(entry: BestiaryEntry, before: BestiaryEntry.Tier) -> void:
	entry_updated.emit(entry.enemy_id)
	if entry.tier() != before:
		entry_unlocked.emit(entry.enemy_id, entry.tier())
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


## Debounced: one save per frame however many entries changed.
func _flush() -> void:
	_flush_queued = false
	var save_manager := ManagerLocator.get_save_manager()
	if save_manager and save_manager.slot_loaded and slot == save_manager.current_slot:
		save_manager.save_game()
