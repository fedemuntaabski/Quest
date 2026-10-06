extends Resource
class_name LootTable

## LootTable (progresion-10): chest tier per floor + the rarity odds of each tier
## (resources/items/loot_table.tres). Chests, the floor-end reward and the Altar
## roll through roll_item().

const DEFAULT_PATH := "res://resources/items/loot_table.tres"

@export var tiers: Array[ChestTier] = []
## Index into `tiers` per floor (index = floor - 1, past the end reuses the last).
@export var tier_by_floor: PackedInt32Array = PackedInt32Array([0, 0, 1, 1, 2])


static func get_default() -> LootTable:
	return load(DEFAULT_PATH) as LootTable


func tier_for_floor(floor_index: int) -> ChestTier:
	if tiers.is_empty():
		return null
	var i := tier_by_floor[clampi(floor_index - 1, 0, tier_by_floor.size() - 1)] if not tier_by_floor.is_empty() else 0
	return tiers[clampi(i, 0, tiers.size() - 1)]


## Item from the floor's chest tier; `min_rarity` drops lower rarities (Altar, secret room).
func roll_item(rng: RandomNumberGenerator, floor_index: int, min_rarity: int = 0, catalog: ItemCatalog = null) -> ItemData:
	catalog = catalog if catalog else ItemCatalog.get_default()
	var tier := tier_for_floor(floor_index)
	if catalog == null:
		return null
	return catalog.pick(rng, tier.rarity_weights if tier else PackedFloat32Array(), min_rarity)
