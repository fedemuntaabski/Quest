extends Node
class_name StatTypes

const HP = "hp"
const STRENGTH = "strength"
const MAGIC = "magic"
const DEXTERITY = "dexterity"

static func get_label(stat_key: String) -> String:
	match stat_key:
		HP:
			return "HP"
			
		STRENGTH:
			return "Fuerza"
		MAGIC:
			return "Magia"
		DEXTERITY:
			return "Agilidad"
		_:
			return stat_key