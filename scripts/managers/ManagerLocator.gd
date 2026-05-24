extends Object
class_name ManagerLocator

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
    if ml and ml is SceneTree:
        return ml.get_first_node_in_group("floating_text_manager")
    return null

static func get_game_state_manager() -> Node:
    var ml = Engine.get_main_loop()
    if ml and ml is SceneTree:
        return ml.get_first_node_in_group("game_state_manager")
    return null
