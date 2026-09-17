extends RefCounted
class_name CharacterDatabase

## CharacterDatabase — static registry of the game's selectable heroes.
## Fixed-order list (not directory-scanned) so UI grids and default-id lookups stay stable.

const CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/warrior.tres",
	"res://resources/characters/mage.tres",
	"res://resources/characters/rogue.tres",
	"res://resources/characters/tank.tres",
]

static var _cache: Array[CharacterData] = []


static func get_all() -> Array[CharacterData]:
	if _cache.is_empty():
		for path in CHARACTER_PATHS:
			var data := load(path) as CharacterData
			if data:
				_cache.append(data)
	return _cache


static func get_by_id(character_id: String) -> CharacterData:
	for data in get_all():
		if data.character_id == character_id:
			return data
	push_warning("CharacterDatabase: unknown character_id '%s', falling back to default." % character_id)
	return get_default()


static func get_default() -> CharacterData:
	return get_all()[0]


static func get_default_id() -> String:
	return get_default().character_id
