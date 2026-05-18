extends Node
class_name CardSystemController

## Orchestrates initialization and lifecycle of the card system for a single player.
## 
## **NOT a singleton.** Each player instance gets its own CardSystemController as a child
## in the hierarchy: Player > PlayerActionController > CardSystemController
##
## Responsibilities:
## 1. Creates and initializes CardManager (manages player deck state: equipped, cooldowns, etc.)
## 2. Creates and initializes CombatCardSystem (handles card play, validation, execution)
## 3. Binds CardManager to HUDController for UI state updates
## 4. Coordinates cooldown ticking and hotbar UI refresh
##
## Initialization Flow:
## - PlayerActionController.setup() creates CardSystemController as child
## - CardSystemController.setup(player, map_manager, card_library) is called
## - _ensure_card_system() creates CardManager and CombatCardSystem as Player children
## - _get_starter_deck() loads deck from CardLibrary (res://resources/cards/card_library.tres)
## - bind_hud() connects CardManager signals to HUDController for hotbar updates
##
## CardLibrary Usage:
## CardLibrary is the single source of truth for card data. It defines:
## - all_cards: Array of all 21 card resources available in the game
## - starter_deck: Default 5 cards the player starts with
## - reward_pool: Cards eligible for random rewards
## Location: res://resources/cards/card_library.tres
##
## Key Signals Connected:
## - CardManager.equipped_changed → Update hotbar UI
## - CardManager.active_index_changed → Refresh selection state
## - CardManager.cooldowns_changed → Update cooldown displays
## - HUDController.hotbar_slot_pressed → Toggle card selection

var player: PlayerMovement = null
var map_manager: MapManager = null
var card_library: CardLibrary = null
var card_manager: CardManager = null
var combat_card_system: CombatCardSystem = null

func setup(p_player: PlayerMovement, p_map_manager: MapManager, p_card_library: CardLibrary = null) -> void:
	player = p_player
	map_manager = p_map_manager
	card_library = p_card_library
	_ensure_card_system()

func _get_starter_deck() -> Array[CardData]:
	# CardLibrary is the single source of truth for starter deck configuration.
	# Located at: res://resources/cards/card_library.tres
	# Starter deck: [sword_card, bow_card, fire_card, focus_card, cripple_card]
	if card_library == null:
		card_library = load("res://resources/cards/card_library.tres") as CardLibrary
	if card_library:
		var starter := card_library.get_starter_deck()
		if not starter.is_empty():
			return starter
	# No fallback: if CardLibrary is unavailable, return empty and log error
	push_error("[CardSystemController] Failed to load CardLibrary starter deck. Check resources/cards/card_library.tres")
	return []

func _ensure_card_system() -> void:
	if player == null:
		return

	card_manager = player.get_node_or_null("CardManager") as CardManager
	if card_manager == null:
		card_manager = CardManager.new()
		card_manager.name = "CardManager"
		player.add_child(card_manager)
	card_manager.max_equipped = 3
	var starter_deck := _get_starter_deck()
	if starter_deck == null or starter_deck.is_empty():
		push_error("[CardSystemController] Failed to load starter deck")
		return
	card_manager.set_deck(starter_deck)

	combat_card_system = player.get_node_or_null("CombatCardSystem") as CombatCardSystem
	if combat_card_system == null:
		combat_card_system = CombatCardSystem.new()
		combat_card_system.name = "CombatCardSystem"
		player.add_child(combat_card_system)

	combat_card_system.setup(player, map_manager, card_manager, player.get_combat_component())

func tick_cooldowns() -> void:
	if card_manager:
		card_manager.tick_cooldowns()

func bind_hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HUDController
	if hud == null:
		# HUD not ready yet; defer the binding
		call_deferred("bind_hud")
		return
	
	# HUD is ready; connect to hud_ready if not already done
	# (This ensures HUD is fully initialized before card system uses it)
	if not hud.hud_ready.is_connected(Callable(self, "_on_hud_ready")):
		hud.hud_ready.connect(Callable(self, "_on_hud_ready"))
	
	# If HUD already emitted hud_ready, call our handler directly
	# (Otherwise, _on_hud_ready will be called automatically)
	call_deferred("_on_hud_ready")

func _on_hud_ready() -> void:
	# Bind card manager to HUD
	var hud := get_tree().get_first_node_in_group("hud") as HUDController
	if hud == null or card_manager == null:
		return
	
	hud.bind_card_manager(card_manager)
	
	# Connect HUD hotbar presses to controller
	var hotbar_cb := Callable(self, "on_hotbar_slot_pressed")
	if not hud.hotbar_slot_pressed.is_connected(hotbar_cb):
		hud.hotbar_slot_pressed.connect(hotbar_cb)
	
	# Connect card manager signals to update UI
	var cooldowns_cb := Callable(self, "update_hotbar_ui")
	var active_idx_cb := Callable(self, "on_active_index_changed")
	var equipped_cb := Callable(self, "update_hotbar_ui")
	if not card_manager.cooldowns_changed.is_connected(cooldowns_cb):
		card_manager.cooldowns_changed.connect(cooldowns_cb)
	if not card_manager.active_index_changed.is_connected(active_idx_cb):
		card_manager.active_index_changed.connect(active_idx_cb)
	if not card_manager.equipped_changed.is_connected(equipped_cb):
		card_manager.equipped_changed.connect(equipped_cb)
	
	# Initial UI refresh
	update_hotbar_ui()

func update_hotbar_ui() -> void:
	if card_manager:
		card_manager.ui_state_changed.emit(card_manager.get_equipped_payload(), card_manager.active_index)

func on_hotbar_slot_pressed(index: int) -> void:
	# Toggle selection behavior
	if card_manager == null:
		return
	if card_manager.active_index == index:
		card_manager.set_active_index(-1)
	else:
		card_manager.set_active_index(index)
	update_hotbar_ui()

func on_active_index_changed(_index: int) -> void:
	update_hotbar_ui()