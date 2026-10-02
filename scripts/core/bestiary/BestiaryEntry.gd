class_name BestiaryEntry
extends RefCounted

## BestiaryEntry: what the player has seen of one enemy type. Serializable to a
## Dictionary (BestiaryService stores one per enemy id in the slot's save file).

enum Tier { UNKNOWN, SEEN, KILLED, MASTERED }

## Kills needed for MASTERED (everything unlocked).
const MASTER_KILLS := 3

var enemy_id: String = ""
var seen_count: int = 0
var kill_count: int = 0
var first_seen_floor: int = 0
var first_kill_floor: int = 0
var max_floor_seen: int = 0


func _init(p_enemy_id: String = "") -> void:
	enemy_id = p_enemy_id


func tier() -> Tier:
	if kill_count >= MASTER_KILLS:
		return Tier.MASTERED
	if kill_count > 0:
		return Tier.KILLED
	return Tier.SEEN if seen_count > 0 else Tier.UNKNOWN


func to_dict() -> Dictionary:
	return {
		"seen": seen_count, "kills": kill_count,
		"first_seen_floor": first_seen_floor, "first_kill_floor": first_kill_floor,
		"max_floor_seen": max_floor_seen,
	}


static func from_dict(p_enemy_id: String, d: Dictionary) -> BestiaryEntry:
	var entry := BestiaryEntry.new(p_enemy_id)
	entry.seen_count = maxi(0, int(d.get("seen", 0)))
	entry.kill_count = maxi(0, int(d.get("kills", 0)))
	entry.first_seen_floor = maxi(0, int(d.get("first_seen_floor", 0)))
	entry.first_kill_floor = maxi(0, int(d.get("first_kill_floor", 0)))
	entry.max_floor_seen = maxi(0, int(d.get("max_floor_seen", 0)))
	return entry
