extends SceneTree

## Genera resources/items/*.tres + item_catalog.tres desde las hojas de arte.
## Los .tres se pueden editar a mano; volver a correr esto los sobrescribe, así
## que cualquier cambio de datos va PRIMERO en la tabla ITEMS.
##   godot --headless --path . --script res://tools/build_items.gd

const W := "res://assets/art/weapons/weapons.png"
const A := "res://assets/art/armor/armours.png"
const P := "res://assets/art/items/potions.png"
const B := "res://assets/art/items/books.png"
const OUT := "res://resources/items/"
const S := ItemData.Slot
const R := ItemData.Rarity
const E := ItemData.ConsumableEffect
const HEAVY: Array[String] = ["warrior", "tank"]
const LIGHT: Array[String] = ["mage", "rogue"]
const MAGE: Array[String] = ["mage"]

## [id, nombre, hoja, columna, fila, slot, rareza, modificadores, descripción, extra]
## extra (opcional): allowed_heroes, stackable/max_stack, effect/value/duration/cooldown.
const ITEMS := [
	["sword_bronze", "Espada de bronce", W, 0, 0, S.WEAPON, R.COMMON, {"attack_damage": 1}, "Un arma sencilla y fiable.", {}],
	["sword_iron", "Espada de hierro", W, 2, 2, S.WEAPON, R.UNCOMMON, {"attack_damage": 2}, "Forjada para las patrullas de la cripta.", {}],
	["sword_steel", "Espada de acero", W, 3, 4, S.WEAPON, R.UNCOMMON, {"attack_damage": 3}, "Acero templado: corta hueso y armadura.", {}],
	["sword_ember", "Hoja de brasa", W, 4, 4, S.WEAPON, R.RARE, {"attack_damage": 3, "attack_interval": -0.1}, "Aún guarda el calor de la fragua que la hizo.", {}],
	["sword_jade", "Hoja de jade", W, 6, 6, S.WEAPON, R.RARE, {"attack_damage": 4}, "Fría al tacto y afilada como una promesa.", {}],
	["sword_gold", "Espada dorada", W, 5, 8, S.WEAPON, R.EPIC, {"attack_damage": 5, "attack_interval": -0.1}, "Perteneció a un rey que no sobrevivió a la cripta.", {}],
	["armor_leather", "Coraza de cuero", A, 0, 0, S.ARMOR, R.COMMON, {"hp": 5}, "Cuero curtido: poco, pero algo.", {}],
	["armor_robe", "Túnica del erudito", A, 2, 4, S.ARMOR, R.UNCOMMON, {"hp": 6, "attack_damage": 1}, "Tela bordada con runas de estudio.", {"allowed_heroes": LIGHT}],
	["armor_iron", "Coraza de hierro", A, 2, 8, S.ARMOR, R.UNCOMMON, {"hp": 10}, "Pesada y honesta.", {}],
	["armor_copper", "Coraza de cobre", A, 3, 11, S.ARMOR, R.RARE, {"hp": 14}, "El cobre verde protege mejor de lo que parece.", {}],
	["armor_steel", "Coraza de acero", A, 7, 13, S.ARMOR, R.EPIC, {"hp": 20}, "Placas ajustadas para quien aguanta en primera línea.", {"allowed_heroes": HEAVY}],
	["armor_gold", "Coraza dorada", A, 3, 15, S.ARMOR, R.EPIC, {"hp": 25}, "Demasiado vistosa para pasar desapercibida.", {"allowed_heroes": HEAVY}],
	["armor_jade", "Coraza de jade", A, 8, 17, S.ARMOR, R.LEGENDARY, {"hp": 30, "attack_damage": 2}, "Dicen que no se ha roto jamás.", {}],
	["potion_health", "Poción de vida", P, 3, 4, S.CONSUMABLE, R.COMMON, {}, "Un trago y las heridas se cierran.", {"stackable": true, "max_stack": 5, "effect": E.HEAL_HP, "value": 10.0, "cooldown": 8.0}],
	["potion_clarity", "Poción de claridad", P, 11, 4, S.CONSUMABLE, R.UNCOMMON, {}, "La mente se aclara y las manos obedecen.", {"stackable": true, "max_stack": 5, "effect": E.SPEED_BUFF_TIMED, "value": 0.3, "duration": 15.0, "cooldown": 20.0}],
	["potion_fury", "Poción de furia", P, 13, 4, S.CONSUMABLE, R.RARE, {}, "Sabe a sangre y a hierro.", {"stackable": true, "max_stack": 5, "effect": E.ATTACK_BUFF_TIMED, "value": 0.5, "duration": 20.0, "cooldown": 25.0}],
	["book_embers", "Grimorio de brasas", B, 3, 0, S.RELIC, R.UNCOMMON, {"attack_damage": 2}, "Las páginas arden sin consumirse.", {"allowed_heroes": MAGE}],
	["book_tides", "Grimorio de mareas", B, 11, 0, S.RELIC, R.RARE, {"attack_interval": -0.15}, "Cada hechizo llega como una ola.", {"allowed_heroes": MAGE}],
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
		item.description = row[8]
		var extra: Dictionary = row[9]
		if extra.has("allowed_heroes"):
			item.allowed_heroes.assign(extra["allowed_heroes"])
		item.stackable = extra.get("stackable", false)
		item.max_stack = extra.get("max_stack", 1)
		item.consumable_effect = extra.get("effect", E.NONE)
		item.effect_value = extra.get("value", 0.0)
		item.effect_duration = extra.get("duration", 0.0)
		item.use_cooldown = extra.get("cooldown", 0.0)
		var path: String = OUT + item.id + ".tres"
		ResourceSaver.save(item, path)
		catalog.items.append(load(path))
	ResourceSaver.save(catalog, ItemCatalog.DEFAULT_PATH)
	print("items: %d" % catalog.items.size())
	quit()
