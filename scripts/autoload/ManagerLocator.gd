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


static func _first_in_group(group: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml and ml is SceneTree:
		return ml.get_first_node_in_group(group)
	return null


static func get_autoload(name: String) -> Node:
	var root = _get_root()
	if root and root.has_node(name):
		return root.get_node(name)
	return null


static func get_save_manager() -> SaveManager:
	return get_autoload("SaveManager") as SaveManager


static func get_player_stats() -> PlayerStats:
	return get_autoload("PlayerStats") as PlayerStats


static func get_party_inventory() -> PartyInventory:
	return get_autoload("PartyInventory") as PartyInventory


static func get_bestiary() -> BestiaryService:
	return get_autoload("BestiaryService") as BestiaryService


## progresion-10: music + SFX (autoload; no class_name, so plain Node).
static func get_audio() -> Node:
	return get_autoload("AudioDirector")


static func get_game_session() -> GameSession:
	return get_autoload("GameSession") as GameSession


static func get_selection_manager() -> SelectionManager:
	return get_autoload("SelectionManager") as SelectionManager


static func get_settings_manager() -> SettingsManager:
	return get_autoload("SettingsManager") as SettingsManager


static func get_steam_manager() -> SteamManager:
	return get_autoload("SteamManager") as SteamManager


## coop-12: the command road (offline: runs locally; client: RPC to the host).
static func get_net_commands() -> CoopCommands:
	return get_autoload("NetCommands") as CoopCommands


## coop-12: the gameplay scene root (group "main2d"; no class_name).
static func get_main2d() -> Node:
	return _first_in_group("main2d")


static func get_resource_manager() -> ResourceManager:
	return get_autoload("ResourceManager") as ResourceManager


static func get_game_state_manager() -> GameStateManager:
	return _first_in_group("game_state_manager") as GameStateManager


static func get_main_orchestrator() -> Main:
	return _first_in_group("main_orchestrator") as Main


static func get_room_manager() -> RoomManager:
	return _first_in_group("room_manager") as RoomManager


## The active (selected) hero; every hero is in group "player" (session 12).
static func get_player() -> Player:
	var ps := get_player_stats()
	var heroes := get_heroes()
	for hero in heroes:
		if ps and hero.stats.hero_id == ps.active_hero_id:
			return hero
	return heroes[0] if not heroes.is_empty() else null


## Every hero of the floor, in party (spawn) order.
static func get_heroes() -> Array[Player]:
	var out: Array[Player] = []
	var ml = Engine.get_main_loop()
	if ml and ml is SceneTree:
		for node in ml.get_nodes_in_group("player"):
			if node is Player:
				out.append(node)
	return out


static func get_hero(hero_id: String) -> Player:
	for hero in get_heroes():
		if hero.stats.hero_id == hero_id:
			return hero
	return null


static func get_tutorial() -> Tutorial:
	return _first_in_group("tutorial") as Tutorial


static func get_hud() -> HUDController:
	return _first_in_group("hud") as HUDController


static func get_relic() -> Relic:
	return _first_in_group("relic") as Relic


static func get_extraction_manager() -> ExtractionManager:
	return _first_in_group("extraction_manager") as ExtractionManager


static func get_enemy_manager() -> EnemyManager:
	return _first_in_group("enemy_manager") as EnemyManager


static func get_exit_indicator() -> ExitIndicator:
	return _first_in_group("exit_indicator") as ExitIndicator


static func get_camera() -> GameCamera:
	return _first_in_group("game_camera") as GameCamera


static func get_floor_manager() -> FloorManager:
	return _first_in_group("floor_manager") as FloorManager


static func get_floating_text_manager() -> FloatingTextManager:
	var ml = Engine.get_main_loop()
	if not (ml and ml is SceneTree):
		return null

	var existing = ml.get_first_node_in_group("floating_text_manager")
	if existing:
		return existing as FloatingTextManager

	var parent: Node = null
	var map_nodes = ml.get_nodes_in_group("map_manager")
	if map_nodes.size() > 0:
		parent = map_nodes[0]
	else:
		parent = ml.get_root()

	var mgr := FloatingTextManager.new()
	mgr.name = "FloatingTextManager"
	parent.add_child(mgr)
	return mgr


## Lazy like the floating text manager: created under the scene root on first use.
static func get_vfx_manager() -> VfxManager:
	var ml = Engine.get_main_loop()
	if not (ml and ml is SceneTree):
		return null
	var existing = ml.get_first_node_in_group("vfx_manager")
	if existing:
		return existing as VfxManager
	var mgr := VfxManager.new()
	mgr.name = "VfxManager"
	ml.get_root().add_child(mgr)
	return mgr


static func flush_saves() -> void:
	var save_mgr := get_save_manager()
	if save_mgr and save_mgr.has_method("save_game"):
		save_mgr.save_game()
