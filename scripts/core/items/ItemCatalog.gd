extends Resource
class_name ItemCatalog

## ItemCatalog: lista de todos los ItemData (resources/items/item_catalog.tres,
## generado por tools/build_items.gd) + sorteo por rareza para los cofres.

const DEFAULT_PATH := "res://resources/items/item_catalog.tres"
const RARITY_WEIGHTS := {
	ItemData.Rarity.COMMON: 50,
	ItemData.Rarity.UNCOMMON: 30,
	ItemData.Rarity.RARE: 14,
	ItemData.Rarity.EPIC: 5,
	ItemData.Rarity.LEGENDARY: 1,
}

@export var items: Array[ItemData] = []


static func get_default() -> ItemCatalog:
	return load(DEFAULT_PATH) as ItemCatalog


func get_item(item_id: String) -> ItemData:
	for item in items:
		if item.id == item_id:
			return item
	return null


## Sorteo ponderado por rareza; `rng` sembrado = mismo cofre en la misma semilla.
func pick(rng: RandomNumberGenerator) -> ItemData:
	var total := 0
	for item in items:
		total += int(RARITY_WEIGHTS[item.rarity])
	if total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	for item in items:
		roll -= int(RARITY_WEIGHTS[item.rarity])
		if roll <= 0:
			return item
	return items.back()
