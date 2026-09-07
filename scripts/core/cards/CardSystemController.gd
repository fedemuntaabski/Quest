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
## 3. Binds HUDController for hotbar input and direct UI refresh
## 4. Coordinates cooldown ticking and hotbar UI refresh
##
## Initialization Flow:
## - PlayerActionController.setup() creates CardSystemController as child
## - CardSystemController.setup(player, map_manager, card_library) is called
## - _ensure_card_system() creates CardManager and CombatCardSystem as Player children
## - _get_starter_deck() loads the curated starter deck from CardLibrary when needed
## - bind_hud() connects HUD input and stores the HUD reference for refreshes
##
## CardLibrary Usage:
## CardLibrary remains the curated fallback for starter-deck and reward-pool
## loading when runtime discovery is not available.
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
var _bound_hud: HUDController = null

func setup(p_player: PlayerMovement, p_map_manager: MapManager, p_card_library: CardLibrary = null) -> void:
	player = p_player
	map_manager = p_map_manager
	card_library = p_card_library
	_ensure_card_system()

func _get_starter_deck() -> Array[CardData]:
	# Use the injected library first, then fall back to the curated on-disk library.
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

	combat_card_system = player.get_node_or_null("CombatCardSystem") as CombatCardSystem
	if combat_card_system == null:
		Logger.debug(Logger.Category.CARDS, "CombatCardSystem not found, creating new instance")
		combat_card_system = CombatCardSystem.new()
		combat_card_system.name = "CombatCardSystem"
		player.add_child(combat_card_system)
		Logger.debug(Logger.Category.CARDS, "CombatCardSystem created and added to player")
	else:
		Logger.debug(Logger.Category.CARDS, "CombatCardSystem found existing instance")

	var starter_deck := _get_starter_deck()
	if starter_deck == null or starter_deck.is_empty():
		push_error("[CardSystemController] Failed to load starter deck; initializing empty deck")
		card_manager.set_deck([])
	else:
		card_manager.set_deck(starter_deck)

	combat_card_system.setup(player, map_manager, card_manager, player.get_combat_component())

func tick_cooldowns() -> void:
	if card_manager:
		card_manager.tick_cooldowns()

func bind_hud_external(hud: HUDController) -> void:
	if hud == null or card_manager == null:
		return
	_bound_hud = hud
	var game_state_manager := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if game_state_manager and not game_state_manager.state_changed.is_connected(Callable(self, "_on_game_state_changed")):
		game_state_manager.state_changed.connect(Callable(self, "_on_game_state_changed"))
	
	# Connect HUD hotbar presses to controller
	var hotbar_cb := Callable(self, "on_hotbar_slot_pressed")
	if not hud.hotbar_slot_pressed.is_connected(hotbar_cb):
		hud.hotbar_slot_pressed.connect(hotbar_cb)
	
	# Connect card manager signals to update UI
	var refresh_cb := Callable(self, "update_hotbar_ui")
	if not card_manager.cooldowns_changed.is_connected(refresh_cb):
		card_manager.cooldowns_changed.connect(refresh_cb)
	if not card_manager.equipped_changed.is_connected(refresh_cb):
		card_manager.equipped_changed.connect(refresh_cb)
	if not card_manager.active_index_changed.is_connected(refresh_cb):
		card_manager.active_index_changed.connect(refresh_cb)
	
	# Initial UI refresh
	update_hotbar_ui()

func update_hotbar_ui() -> void:
	if card_manager:
		# Get base payload from CardManager and enrich with combat-level playability
		var payload := card_manager.get_equipped_payload()
		# Iterate payload and compute full_playable where we can (self-target or hovered enemy)
		for i in range(payload.size()):
			var entry: Dictionary = payload[i] as Dictionary
			var used_prediction: bool = false
			if not entry.has("card"):
				continue
			var card: CardData = entry.get("card") as CardData
			var cooldown_ok: bool = bool(entry.get("cooldown_ok", entry.get("is_usable", true)))
			var full_playable: bool = cooldown_ok
			var playability_reason: String = ""

			if combat_card_system and card != null:
				if card.target_type == "self":
					var validation := combat_card_system.get_card_validation(card, player)
					if card.targeting_profile == "dash" and not bool(validation.get("valid", false)):
						validation = combat_card_system.get_card_validation(card, player)
					full_playable = bool(validation.get("valid", false))
					playability_reason = validation.get("reason", null)
				elif card.target_type == "enemy":
					# If we have a hovered actor, validate against it; otherwise try to predict
					var validated := false
					if map_manager and map_manager.hovered_cell != Vector2i(-999, -999):
						var target_actor := map_manager.get_actor_at_cell(map_manager.hovered_cell)
						if target_actor != null:
							var validation2 := combat_card_system.get_card_validation(card, target_actor)
							full_playable = bool(validation2.get("valid", false))
							playability_reason = str(validation2.get("reason", ""))
							validated = true
					# Predict nearest enemy in the room if no hovered target available
					if not validated and map_manager and player:
						var enemy_mgr = _resolve_enemy_manager()
						if enemy_mgr != null:
							var enemies = enemy_mgr.get_enemies()
							if enemies and enemies.size() > 0:
								# Find nearest alive enemy by chebyshev distance
								var player_cell = CardTargeting.get_actor_cell(player, map_manager)
								var nearest: Node = null
								var best_dist := 99999
								for e in enemies:
									if e == null:
										continue
									if not e.has_method("get_combat_component") and e.get_node_or_null("CombatComponent") == null:
										continue
									var ec = CardTargeting.get_actor_cell(e, map_manager)
									if ec == null or player_cell == null:
										continue
									var dist := CardTargeting.get_chebyshev_distance(player_cell, ec)
									if dist < best_dist:
										best_dist = dist
										nearest = e
								if nearest != null:
									var validation3 := combat_card_system.get_card_validation(card, nearest)
									full_playable = bool(validation3.get("valid", false))
									playability_reason = str(validation3.get("reason", ""))
									validated = true
									used_prediction = true

			entry["cooldown_ok"] = cooldown_ok
			entry["full_playable"] = full_playable
			entry["playability_reason"] = playability_reason
			var readable_reason := _human_readable_playability_reason(playability_reason)
			if used_prediction:
				if readable_reason != "":
					readable_reason = "%s (predicted)" % readable_reason
				else:
					readable_reason = "(predicted)"
			entry["playability_reason_readable"] = readable_reason
			payload[i] = entry

		if _bound_hud:
			_bound_hud.update_hotbar(payload, card_manager.active_index)

func clear_targeting_state() -> void:
	Logger.debug(Logger.Category.CARDS, "clear_targeting_state()")
	if card_manager and card_manager.active_index != -1:
		card_manager.set_active_index(-1)
	var action_controller := get_parent() as PlayerActionController
	if action_controller and action_controller.has_method("clear_hover_targeting_state"):
		action_controller.clear_hover_targeting_state()

func _on_game_state_changed(new_state: GameStateManager.State, _old_state: GameStateManager.State) -> void:
	Logger.debug(Logger.Category.CARDS, "_on_game_state_changed: %s -> %s" % [GameStateManager.State.keys()[_old_state], GameStateManager.State.keys()[new_state]])
	if new_state != GameStateManager.State.ACTIVE:
		clear_targeting_state()

func on_hotbar_slot_pressed(index: int) -> void:
	# Toggle selection behavior
	if card_manager == null:
		return
	var game_state_manager := get_tree().get_first_node_in_group("game_state_manager") as GameStateManager
	if game_state_manager and not game_state_manager.can_process_input():
		Logger.debug(Logger.Category.CARDS, "on_hotbar_slot_pressed: ignored, game state is %s" % GameStateManager.State.keys()[game_state_manager.get_state()])
		return
	if player and player.has_method("can_accept_input") and not player.can_accept_input():
		Logger.debug(Logger.Category.CARDS, "on_hotbar_slot_pressed: ignored, player cannot accept input")
		return
	if card_manager.active_index == index:
		card_manager.set_active_index(-1)
	else:
		card_manager.set_active_index(index)


func _human_readable_playability_reason(reason: String) -> String:
	if reason == null or reason == "":
		return ""
	match reason:
		"card_on_cooldown":
			return "En enfriamiento"
		"out_of_range":
			return "Fuera de rango"
		"no_target":
			return "Sin objetivo"
		"missing_target_stats":
			return "Objetivo inválido"
		"target_dead":
			return "Objetivo muerto"
		"source_dead":
			return "Fuente muerta"
		"missing_card":
			return "Carta faltante"
		"missing_card_manager":
			return "Gestor de cartas faltante"
		"missing_combat_component":
			return "Componente de combate faltante"
		"missing_stats":
			return "Estadísticas faltantes"
		"stale_snapshot":
			return "Instantánea obsoleta"
		"invalid_destination":
			return "Destino inválido"
		_:
			return str(reason)


func request_set_active_index(index: int) -> void:
	# Canonical external API for requesting selection changes.
	# CardManager remains the single data owner; CardSystemController is the
	# canonical external writer that coordinates UI refresh and any higher-
	# level invariants.
	if card_manager == null:
		push_error("[CardSystemController] request_set_active_index: card_manager is NULL")
		return
	card_manager.set_active_index(index)


func _resolve_enemy_manager():
	# Preferred accessor: MapManager.get_enemy_manager()
	if map_manager == null:
		return null
	if map_manager.has_method("get_enemy_manager"):
		var em = map_manager.get_enemy_manager()
		if em != null:
			return em

	return null
