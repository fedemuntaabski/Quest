extends Resource
class_name PartyConfig

## PartyConfig: which heroes Main2d spawns every floor (session 12; fixed
## party, no roster/recruiting yet). Fallback when GameSession holds no pick
## (editor F6, multiplayer): the saved hero comes first, then `companion_ids`
## in order (skipping it) until `party_size`, which also caps a GameSession pick.
## party_size 1 = the single-hero game.

@export_range(1, 3) var party_size: int = 2
## CharacterDatabase ids, in fill order.
@export var companion_ids: Array[String] = ["warrior", "mage", "rogue"]
## Horizontal px between the sprites of heroes standing in the same zone.
@export var sprite_spacing: float = 28.0


func get_party_ids(selected_id: String) -> Array[String]:
	var ids: Array[String] = [selected_id]
	for id in companion_ids:
		if ids.size() >= party_size:
			break
		if not ids.has(id):
			ids.append(id)
	return ids


## Sprite shift of hero `index` of `count`, centered on the zone.
func sprite_offset(index: int, count: int) -> Vector2:
	return Vector2((index - (count - 1) * 0.5) * sprite_spacing, 0.0)
