class_name ItemStack
extends RefCounted

## ItemStack: `count` copies of one ItemData in the party stash (only stackable
## items ever hold more than 1).

var item: ItemData
var count: int = 1


func _init(p_item: ItemData = null, p_count: int = 1) -> void:
	item = p_item
	count = p_count
