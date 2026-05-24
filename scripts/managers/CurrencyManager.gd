extends Node

signal gold_changed(amount: int)

func _ready() -> void:
	add_to_group("currency_manager")

func get_gold() -> int:
	var save_mgr := get_node_or_null("/root/SaveManager")
	return save_mgr.gold if save_mgr else 0

func add_gold(amount: int, world_pos: Vector2 = Vector2.ZERO) -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return
	_commit_gold(save_mgr, save_mgr.gold + max(amount, 0))
	if world_pos != Vector2.ZERO:
		_spawn_gold_text(amount, world_pos)

func spend_gold(amount: int) -> bool:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return false
	if save_mgr.gold < amount:
		return false
	_commit_gold(save_mgr, save_mgr.gold - amount)
	return true

func set_gold(amount: int) -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr == null:
		return
	_commit_gold(save_mgr, amount)

func reset() -> void:
	set_gold(0)

func _commit_gold(save_mgr: Node, amount: int) -> void:
	save_mgr.gold = max(0, amount)
	save_mgr.save_game()
	gold_changed.emit(save_mgr.gold)

func _spawn_gold_text(amount: int, world_pos: Vector2) -> void:
	if amount <= 0:
		return
	var text_mgr := get_tree().get_first_node_in_group("floating_text_manager") as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(world_pos, "+%d g" % amount, QuestPalette.CURRENCY_GOLD_POPUP)
