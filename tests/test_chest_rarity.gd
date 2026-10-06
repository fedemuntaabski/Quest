extends SceneTree

## Chest rarity table (progresion-10, LootTable + ItemCatalog.pick):
##   - chest tier per floor: madera 1-2, hierro 3-4, oro 5 (and past the end)
##   - every tier's weights are > 0 in total; better tiers give more rare+ items
##   - 20k seeded rolls per tier land within 3 points of the table's odds
##   - min_rarity (Altar, secret room) never yields anything lower
##   - same seed = same item
##   godot --headless --path . --script res://tests/test_chest_rarity.gd

const ROLLS := 20000
const TOLERANCE := 0.03

var failures: Array[String] = []


func _initialize() -> void:
	var table := LootTable.get_default()
	var catalog := ItemCatalog.get_default()
	_expect(table != null and table.tiers.size() == 3, "loot_table.tres: 3 tiers")
	_test_tiers_by_floor(table)
	_test_frequencies(table, catalog)
	_test_min_rarity(table)
	_test_determinism(table)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_chest_rarity: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _test_tiers_by_floor(table: LootTable) -> void:
	var names := ["Madera", "Madera", "Hierro", "Hierro", "Oro", "Oro"]
	for f in range(1, 7):
		var tier := table.tier_for_floor(f)
		_expect(tier != null and tier.display_name == names[f - 1], "floor %d: tier %s, expected %s" % [f, tier.display_name if tier else "null", names[f - 1]])
	var prev_rare := -1.0
	for tier in table.tiers:
		var total := 0.0
		var rare := 0.0
		for i in tier.rarity_weights.size():
			total += tier.rarity_weights[i]
			if i >= ItemData.Rarity.RARE:
				rare += tier.rarity_weights[i]
		_expect(total > 0.0 and tier.rarity_weights.size() == ItemData.Rarity.size(), "%s: weights %s" % [tier.display_name, tier.rarity_weights])
		_expect(rare / total > prev_rare, "%s: rare+ share %.2f not above the previous tier" % [tier.display_name, rare / total])
		prev_rare = rare / total


func _test_frequencies(table: LootTable, catalog: ItemCatalog) -> void:
	var present := {}
	for item in catalog.items:
		present[item.rarity] = true
	for tier in table.tiers:
		var total := 0.0
		for r in tier.rarity_weights.size():
			if present.has(r):
				total += tier.rarity_weights[r]
		var counts := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		for i in ROLLS:
			var item := catalog.pick(rng, tier.rarity_weights)
			counts[item.rarity] = int(counts.get(item.rarity, 0)) + 1
		for r in tier.rarity_weights.size():
			var expected := tier.rarity_weights[r] / total if present.has(r) else 0.0
			var got := float(counts.get(r, 0)) / ROLLS
			_expect(absf(got - expected) <= TOLERANCE, "%s: rarity %s at %.3f, table says %.3f" % [tier.display_name, ItemData.RARITY_LABELS[r], got, expected])


func _test_min_rarity(table: LootTable) -> void:
	for f in range(1, 6):
		var rng := RandomNumberGenerator.new()
		rng.seed = f
		for i in 500:
			var item := table.roll_item(rng, f, ItemData.Rarity.RARE)
			if item == null or item.rarity < ItemData.Rarity.RARE:
				failures.append("floor %d: min RARE gave %s" % [f, item.id if item else "null"])
				return


func _test_determinism(table: LootTable) -> void:
	for f in range(1, 6):
		var a := RandomNumberGenerator.new()
		var b := RandomNumberGenerator.new()
		a.seed = 99 + f
		b.seed = 99 + f
		_expect(table.roll_item(a, f).id == table.roll_item(b, f).id, "floor %d: same seed, different item" % f)
