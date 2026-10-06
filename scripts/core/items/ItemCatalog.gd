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


## Sorteo en dos pasos: primero la rareza (pesos `rarity_weights[rareza]`, vacío =
## RARITY_WEIGHTS; solo rarezas >= `min_rarity` que tengan ítems), después un ítem
## uniforme de esa rareza. `rng` sembrado = mismo cofre en la misma semilla.
func pick(rng: RandomNumberGenerator, rarity_weights: PackedFloat32Array = PackedFloat32Array(), min_rarity: int = 0) -> ItemData:
	var by_rarity := {}
	for item in items:
		if item.rarity >= min_rarity:
			if not by_rarity.has(item.rarity):
				by_rarity[item.rarity] = []
			by_rarity[item.rarity].append(item)
	var total := 0.0
	for rarity in by_rarity:
		total += rarity_weight(rarity, rarity_weights)
	if total <= 0.0:
		# Every allowed rarity weighs 0 (e.g. a wooden chest asked for EPIC+): the lowest allowed.
		var keys := by_rarity.keys()
		if keys.is_empty():
			return null
		keys.sort()
		var pool: Array = by_rarity[keys[0]]
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll := rng.randf() * total
	for rarity in by_rarity:
		roll -= rarity_weight(rarity, rarity_weights)
		if roll < 0.0:
			var pool: Array = by_rarity[rarity]
			return pool[rng.randi_range(0, pool.size() - 1)]
	var last: Array = by_rarity[by_rarity.keys().back()]
	return last[rng.randi_range(0, last.size() - 1)]


static func rarity_weight(rarity: int, rarity_weights: PackedFloat32Array) -> float:
	if rarity_weights.is_empty():
		return float(RARITY_WEIGHTS[rarity])
	return maxf(rarity_weights[rarity], 0.0) if rarity < rarity_weights.size() else 0.0
