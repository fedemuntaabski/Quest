extends SceneTree

## Genera resources/items/*.tres + item_catalog.tres desde las hojas de arte.
## Los .tres se pueden editar a mano; volver a correr esto los sobrescribe.
##   godot --headless --path . --script res://tools/build_items.gd

const W := "res://assets/art/weapons/weapons.png"
const A := "res://assets/art/armor/armours.png"
const P := "res://assets/art/items/potions.png"
const B := "res://assets/art/items/books.png"
const OUT := "res://resources/items/"
const S := ItemData.Slot
const R := ItemData.Rarity

## [id, nombre, hoja, columna, fila, slot, rareza, modificadores]
const ITEMS := [
	["sword_bronze", "Espada de bronce", W, 0, 0, S.WEAPON, R.COMMON, {"attack_damage": 1}],
	["sword_iron", "Espada de hierro", W, 2, 2, S.WEAPON, R.UNCOMMON, {"attack_damage": 2}],
	["sword_steel", "Espada de acero", W, 3, 4, S.WEAPON, R.UNCOMMON, {"attack_damage": 3}],
	["sword_ember", "Hoja de brasa", W, 4, 4, S.WEAPON, R.RARE, {"attack_damage": 3, "attack_interval": -0.1}],
	["sword_jade", "Hoja de jade", W, 6, 6, S.WEAPON, R.RARE, {"attack_damage": 4}],
	["sword_gold", "Espada dorada", W, 5, 8, S.WEAPON, R.EPIC, {"attack_damage": 5, "attack_interval": -0.1}],
	["armor_leather", "Coraza de cuero", A, 0, 0, S.ARMOR, R.COMMON, {"hp": 5}],
	["armor_robe", "Túnica del erudito", A, 2, 4, S.ARMOR, R.UNCOMMON, {"hp": 6, "attack_damage": 1}],
	["armor_iron", "Coraza de hierro", A, 2, 8, S.ARMOR, R.UNCOMMON, {"hp": 10}],
	["armor_copper", "Coraza de cobre", A, 3, 11, S.ARMOR, R.RARE, {"hp": 14}],
	["armor_steel", "Coraza de acero", A, 7, 13, S.ARMOR, R.EPIC, {"hp": 20}],
	["armor_gold", "Coraza dorada", A, 3, 15, S.ARMOR, R.EPIC, {"hp": 25}],
	["armor_jade", "Coraza de jade", A, 8, 17, S.ARMOR, R.LEGENDARY, {"hp": 30, "attack_damage": 2}],
	["potion_health", "Poción de vida", P, 3, 4, S.CONSUMABLE, R.COMMON, {"hp": 10}],
	["potion_clarity", "Poción de claridad", P, 11, 4, S.CONSUMABLE, R.UNCOMMON, {"attack_interval": -0.05}],
	["potion_fury", "Poción de furia", P, 13, 4, S.CONSUMABLE, R.RARE, {"attack_damage": 2}],
	["book_embers", "Grimorio de brasas", B, 3, 0, S.RELIC, R.UNCOMMON, {"attack_damage": 2}],
	["book_tides", "Grimorio de mareas", B, 11, 0, S.RELIC, R.RARE, {"attack_interval": -0.15}],
]


func _init() -> void:
	var catalog := ItemCatalog.new()
	for row: Array in ITEMS:
		var item := ItemData.new()
		item.id = row[0]
		item.display_name = row[1]
		var icon := AtlasTexture.new()
		icon.atlas = load(row[2])
		icon.region = Rect2(row[3] * 16, row[4] * 16, 16, 16)
		item.icon = icon
		item.slot = row[5]
		item.rarity = row[6]
		item.modifiers = row[7]
		var path: String = OUT + item.id + ".tres"
		ResourceSaver.save(item, path)
		catalog.items.append(load(path))
	ResourceSaver.save(catalog, ItemCatalog.DEFAULT_PATH)
	print("items: %d" % catalog.items.size())
	quit()
