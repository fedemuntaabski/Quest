extends Resource
class_name ItemData

## ItemData: un objeto (arma, armadura, consumible, reliquia). Equipo (arma,
## armadura, reliquia) suma `modifiers` a su portador mientras está equipado
## (PartyInventory -> PlayerStats, tercera capa base -> nivel -> equipo).
## Los consumibles no tienen modifiers: se gastan y aplican `consumable_effect`
## (InventoryComponent). `modifiers` usa solo stats que ya existen: hp (vida
## máx.), attack_damage, attack_interval (delta en segundos, negativo = más
## rápido) y attack_range (px). Los .tres de resources/items/ los genera
## tools/build_items.gd y se pueden editar a mano.

enum Slot { WEAPON, ARMOR, CONSUMABLE, RELIC }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
enum ConsumableEffect {
	NONE,
	HEAL_HP,            ## cura `effect_value` de vida
	ATTACK_BUFF_TIMED,  ## daño x(1 + value) durante `effect_duration` s
	SPEED_BUFF_TIMED,   ## intervalo de ataque x(1 - value) durante `effect_duration` s
}

const MODIFIER_KEYS := ["hp", "attack_damage", "attack_interval", "attack_range"]
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
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export var modifiers: Dictionary = {}
## Vacío = cualquier héroe; si no, ids de CharacterData que pueden llevarlo.
@export var allowed_heroes: Array[String] = []
@export var stackable: bool = false
@export var max_stack: int = 1

@export_group("Consumible")
@export var consumable_effect: ConsumableEffect = ConsumableEffect.NONE
@export var effect_value: float = 0.0
@export var effect_duration: float = 0.0
## Segundos de espera (tiempo de juego) antes de que ese héroe use otro consumible igual.
@export var use_cooldown: float = 0.0


func is_consumable() -> bool:
	return slot == Slot.CONSUMABLE


func color() -> Color:
	return RARITY_COLORS[rarity]


## "+10 Vida · +2 Daño · -0.10 s Intervalo · +20 px Alcance"
func describe_modifiers() -> String:
	var parts: Array[String] = []
	if modifiers.has("hp"):
		parts.append("%+d Vida" % int(modifiers["hp"]))
	if modifiers.has("attack_damage"):
		parts.append("%+d Daño" % int(modifiers["attack_damage"]))
	if modifiers.has("attack_interval"):
		parts.append("%+.2f s Intervalo" % float(modifiers["attack_interval"]))
	if modifiers.has("attack_range"):
		parts.append("%+d px Alcance" % int(modifiers["attack_range"]))
	return " · ".join(parts)


## "Cura 10 de vida" / "+50 % de daño durante 20 s"
func describe_effect() -> String:
	match consumable_effect:
		ConsumableEffect.HEAL_HP:
			return "Cura %d de vida" % roundi(effect_value)
		ConsumableEffect.ATTACK_BUFF_TIMED:
			return "+%d %% de daño durante %d s" % [roundi(effect_value * 100.0), roundi(effect_duration)]
		ConsumableEffect.SPEED_BUFF_TIMED:
			return "+%d %% de velocidad de ataque durante %d s" % [roundi(effect_value * 100.0), roundi(effect_duration)]
	return ""


## What it does, whichever kind of item it is.
func describe_stats() -> String:
	return describe_effect() if is_consumable() else describe_modifiers()


## Hero ids that may carry it, "" when anyone can.
func describe_restriction() -> String:
	return "" if allowed_heroes.is_empty() else "Solo: %s" % ", ".join(allowed_heroes)
