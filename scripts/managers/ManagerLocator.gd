extends Object
class_name ManagerLocator

# ManagerLocator: convenience helper to find common manager singletons
# in the scene tree. NOTE: this is an aggressive helper in places
# (e.g. `get_floating_text_manager`) and may create a manager at runtime
# if none exists; callers should treat results as possibly-created nodes.

static func _get_root() -> Node:
    var ml = Engine.get_main_loop()
    if ml == null:
        return null
    if ml is SceneTree:
        return ml.get_root()
    return null

static func _find_child_by_name(name: String) -> Node:
    var root = _get_root()
    if root == null:
        return null
    for child in root.get_children():
        if child is Node and child.name == name:
            return child
    return null

static func get_save_manager() -> Node:
    return _find_child_by_name("SaveManager")

static func get_currency_manager() -> Node:
    return _find_child_by_name("CurrencyManager")

static func get_player_stats() -> Node:
    return _find_child_by_name("PlayerStats")

static func get_theme_manager() -> Node:
    return _find_child_by_name("ThemeManager")

static func get_floating_text_manager() -> Node:
    var ml = Engine.get_main_loop()
    if not (ml and ml is SceneTree):
        return null

    var existing = ml.get_first_node_in_group("floating_text_manager")
    if existing:
        return existing

    # Aggressive helper: create a FloatingTextManager if none exists.
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

static func get_game_state_manager() -> Node:
    var ml = Engine.get_main_loop()
    if ml and ml is SceneTree:
        return ml.get_first_node_in_group("game_state_manager")
    return null

static func flush_saves() -> void:
    var currency := get_currency_manager()
    if currency and currency.has_method("flush_save"):
        currency.flush_save()
