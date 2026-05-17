extends Node
class_name CardSystemController

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
	if card_library == null:
		card_library = load("res://resources/cards/card_library.tres") as CardLibrary
	if card_library:
		var starter := card_library.get_starter_deck()
		if not starter.is_empty():
			return starter
	# Fallback default deck
	var DEFAULT_DECK: Array[CardData] = [
		load("res://resources/cards/sword_card.tres"),
		load("res://resources/cards/bow_card.tres"),
		load("res://resources/cards/fire_card.tres"),
		load("res://resources/cards/focus_card.tres"),
		load("res://resources/cards/cripple_card.tres"),
	]
	return DEFAULT_DECK

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
		# fallback to DEFAULT_DECK in PlayerActionController if needed
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
		call_deferred("bind_hud")
		return
	# Bind card manager to HUD
	if hud and card_manager:
		hud.bind_card_manager(card_manager)
		# Connect HUD hotbar presses to controller
		if not hud.hotbar_slot_pressed.is_connected(self.on_hotbar_slot_pressed):
			hud.hotbar_slot_pressed.connect(self.on_hotbar_slot_pressed)
	# Connect card manager signals to update UI
	if card_manager:
		if not card_manager.cooldowns_changed.is_connected(self.update_hotbar_ui):
			card_manager.cooldowns_changed.connect(self.update_hotbar_ui)
		if not card_manager.active_index_changed.is_connected(self.on_active_index_changed):
			card_manager.active_index_changed.connect(self.on_active_index_changed)
		if not card_manager.equipped_changed.is_connected(self.update_hotbar_ui):
			card_manager.equipped_changed.connect(self.update_hotbar_ui)
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