extends Object
class_name ManagerLocator

## ManagerLocator — Service locator for core game singletons and managers.

static func _get_root() -> Node:
	var ml = Engine.get_main_loop()
	if ml == null:
		return null
	if ml is SceneTree:
		return ml.get_root()
	return null


static func get_autoload(name: String) -> Node:
	var root = _get_root()
	if root and root.has_node(name):
		return root.get_node(name)
	return null


static func get_save_manager() -> Node:
	return get_autoload("SaveManager")


static func get_currency_manager() -> Node:
	return get_autoload("CurrencyManager")


static func get_player_stats() -> Node:
	return get_autoload("PlayerStats")


static func get_settings_manager() -> Node:
	return get_autoload("SettingsManager")


static func get_game_state_manager() -> GameStateManager:
	var ml = Engine.get_main_loop()
	if ml and ml is SceneTree:
		return ml.get_first_node_in_group("game_state_manager") as GameStateManager
	return null


static func get_floating_text_manager() -> Node:
	var ml = Engine.get_main_loop()
	if not (ml and ml is SceneTree):
		return null

	var existing = ml.get_first_node_in_group("floating_text_manager")
	if existing:
		return existing

	var parent: Node = null
	var map_nodes = ml.get_nodes_in_group("map_manager")
	if map_nodes.size() > 0:
		parent = map_nodes[0]
	else:
		parent = ml.get_root()

	var fscene := preload("res://scripts/ui/visual/FloatingTextManager.gd")
	var mgr := fscene.new()
	mgr.name = "FloatingTextManager"
	parent.add_child(mgr)
	return mgr


static func flush_saves() -> void:
	var currency := get_currency_manager()
	if currency and currency.has_method("flush_save"):
		currency.flush_save()
	var save_mgr := get_save_manager()
	if save_mgr and save_mgr.has_method("save_game"):
		save_mgr.save_game()
