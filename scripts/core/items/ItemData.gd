extends Resource
class_name ItemData

## ItemData: un objeto (arma, armadura, consumible, reliquia). Solo datos: el
## juego aún no tiene sistema de equipo, así que hoy se muestran (cofres,
## Pickup, CharacterPopup) pero no se aplican. `modifiers` usa solo las stats
## que ya existen en CharacterStats: hp (vida máx.), attack_damage y
## attack_interval (delta en segundos, negativo = más rápido).
## Los .tres de resources/items/ se generan con tools/build_items.gd y se
## pueden editar a mano.

enum Slot { WEAPON, ARMOR, CONSUMABLE, RELIC }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const MODIFIER_KEYS := ["hp", "attack_damage", "attack_interval"]
const SLOT_LABELS := {Slot.WEAPON: "Arma", Slot.ARMOR: "Armadura", Slot.CONSUMABLE: "Consumible", Slot.RELIC: "Reliquia"}
const RARITY_LABELS := {Rarity.COMMON: "Común", Rarity.UNCOMMON: "Poco común", Rarity.RARE: "Raro", Rarity.EPIC: "Épico", Rarity.LEGENDARY: "Legendario"}
const RARITY_COLORS := {
	Rarity.COMMON: Color(0.8, 0.78, 0.72),
	Rarity.UNCOMMON: Color(0.45, 0.8, 0.45),
	Rarity.RARE: Color(0.4, 0.6, 0.95),
	Rarity.EPIC: Color(0.7, 0.45, 0.9),
	Rarity.LEGENDARY: Color(0.95, 0.7, 0.25),
}

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var modifiers: Dictionary = {}


## "+10 Vida · +2 Daño · -0.10 s Intervalo"
func describe_modifiers() -> String:
	var parts: Array[String] = []
	if modifiers.has("hp"):
		parts.append("%+d Vida" % int(modifiers["hp"]))
	if modifiers.has("attack_damage"):
		parts.append("%+d Daño" % int(modifiers["attack_damage"]))
	if modifiers.has("attack_interval"):
		parts.append("%+.2f s Intervalo" % float(modifiers["attack_interval"]))
	return " · ".join(parts)
