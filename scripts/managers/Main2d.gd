extends Node2D

# ─────────────────────────────────────────────
# NODES
# ─────────────────────────────────────────────
@onready var map_manager: MapManager = $MapManager
@onready var hud: HUDController = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var death_overlay: CanvasLayer = $DeathOverlay
@onready var victory_overlay: VictoryOverlay = $VictoryOverlay
@onready var enemy_manager: EnemyManager = $MapManager/EnemyManager

@onready var retry_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/RetryButton
@onready var exit_button: Button = $DeathOverlay/CenterContainer/VBoxContainer/ButtonsHBox/ExitButton
@onready var death_gold_label: Label = $DeathOverlay/CenterContainer/VBoxContainer/GoldLabel

var game_state_manager: GameStateManager
var card_reward_manager: CardRewardManager

# ─────────────────────────────────────────────
# STATE
# ─────────────────────────────────────────────
var room_timer: Main2dRoomTimer
var death_handler: Main2dDeathHandler

var visited_rooms: Array[int] = []
var enemies_killed: int = 0
var rooms_cleared: int = 0
var _is_dead: bool = false
var _room_timer_paused: bool = false
var _victory_triggered: bool = false

var tutorial_layer: Node = null
var _run_gold_start: int = 0
var _reward_pending: bool = false

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_content_scaling()

	room_timer = Main2dRoomTimer.new()
	death_handler = Main2dDeathHandler.new()
	death_handler.setup(self, death_overlay, death_gold_label)

	_setup_managers()
	_connect_signals()
	_load_tutorial_if_needed()

	_reset_room_timer()

	# Capture starting gold for this run to compute run-earned gold later
	var currency := get_node_or_null("/root/CurrencyManager") as CurrencyManager
	if currency:
		_run_gold_start = int(currency.get_gold())

func _setup_content_scaling() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _setup_managers() -> void:
	# GameStateManager
	game_state_manager = get_node_or_null("GameStateManager") as GameStateManager
	if game_state_manager == null:
		game_state_manager = GameStateManager.new()
		game_state_manager.name = "GameStateManager"
		add_child(game_state_manager)

	# CardRewardManager
	card_reward_manager = get_node_or_null("CardRewardManager") as CardRewardManager
	if card_reward_manager == null:
		card_reward_manager = CardRewardManager.new()
		card_reward_manager.name = "CardRewardManager"
		add_child(card_reward_manager)
	
	# Connect reward signals
	if card_reward_manager:
		var reward_cb := Callable(self, "_on_reward_completed")
		if not card_reward_manager.reward_completed.is_connected(reward_cb):
			card_reward_manager.reward_completed.connect(reward_cb)

# ─────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────
func _dg() -> DungeonGenerator:
	return map_manager.dungeon_generator

# ─────────────────────────────────────────────
# SIGNALS
# ─────────────────────────────────────────────
func _connect_signals() -> void:
	_connect_dungeon()
	_connect_player()
	_connect_ui()

func _connect_dungeon() -> void:
	var dg = _dg()
	if not dg:
		return

	if not dg.room_changed.is_connected(Callable(self, "_on_room_changed")):
		dg.room_changed.connect(Callable(self, "_on_room_changed"))

	if enemy_manager and not enemy_manager.room_cleared.is_connected(Callable(self, "_on_room_cleared")):
		enemy_manager.room_cleared.connect(Callable(self, "_on_room_cleared"))

	if enemy_manager and not enemy_manager.enemy_defeated_global.is_connected(Callable(self, "_on_enemy_defeated")):
		enemy_manager.enemy_defeated_global.connect(Callable(self, "_on_enemy_defeated"))

	if enemy_manager and enemy_manager.has_signal("boss_defeated") and not enemy_manager.boss_defeated.is_connected(Callable(self, "_on_boss_defeated")):
		enemy_manager.boss_defeated.connect(Callable(self, "_on_boss_defeated"))

func _connect_player() -> void:
	var player_stats = get_node_or_null("/root/PlayerStats")

	if player_stats and not player_stats.player_died.is_connected(Callable(self, "_on_player_died")):
		player_stats.player_died.connect(Callable(self, "_on_player_died"))

func _connect_ui() -> void:
	if retry_button and not retry_button.pressed.is_connected(Callable(self, "_on_retry_pressed")):
		retry_button.pressed.connect(Callable(self, "_on_retry_pressed"))

	if exit_button and not exit_button.pressed.is_connected(Callable(self, "_on_return_pressed")):
		exit_button.pressed.connect(Callable(self, "_on_return_pressed"))

	if victory_overlay and not victory_overlay.retry_requested.is_connected(Callable(self, "_on_retry_pressed")):
		victory_overlay.retry_requested.connect(Callable(self, "_on_retry_pressed"))
	if victory_overlay and not victory_overlay.exit_requested.is_connected(Callable(self, "_on_return_pressed")):
		victory_overlay.exit_requested.connect(Callable(self, "_on_return_pressed"))

	if pause_menu and pause_menu.has_method("close_menu"):
		pause_menu.close_menu()

	if pause_menu and not pause_menu.exit_requested.is_connected(Callable(self, "_on_pause_exit_requested")):
		pause_menu.exit_requested.connect(Callable(self, "_on_pause_exit_requested"))

	if hud and not hud.reward_card_selected.is_connected(Callable(self, "_on_reward_card_selected")):
		hud.reward_card_selected.connect(Callable(self, "_on_reward_card_selected"))
	if hud and not hud.reward_skipped.is_connected(Callable(self, "_on_reward_skipped")):
		hud.reward_skipped.connect(Callable(self, "_on_reward_skipped"))
	if hud and not hud.reward_card_replace_selected.is_connected(Callable(self, "_on_reward_card_replace_selected")):
		hud.reward_card_replace_selected.connect(Callable(self, "_on_reward_card_replace_selected"))

	if game_state_manager and not game_state_manager.reward_entered.is_connected(Callable(self, "_on_reward_entered")):
		game_state_manager.reward_entered.connect(Callable(self, "_on_reward_entered"))
	if game_state_manager and not game_state_manager.reward_exited.is_connected(Callable(self, "_on_reward_exited")):
		game_state_manager.reward_exited.connect(Callable(self, "_on_reward_exited"))
	if game_state_manager and not game_state_manager.victory_entered.is_connected(Callable(self, "_on_victory_entered")):
		game_state_manager.victory_entered.connect(Callable(self, "_on_victory_entered"))

# ─────────────────────────────────────────────
# TUTORIAL 
# ─────────────────────────────────────────────
func _load_tutorial_if_needed() -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if not save_mgr or not save_mgr.first_time_player:
		return

	var scene := load("res://scenes/TutorialLayer.tscn")
	if not scene:
		return

	tutorial_layer = scene.instantiate()
	if tutorial_layer is Node:
		tutorial_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(tutorial_layer)
	_room_timer_paused = true

	if tutorial_layer.has_signal("tutorial_started"):
		tutorial_layer.connect("tutorial_started", _on_tutorial_started)
	if tutorial_layer.has_signal("tutorial_finished"):
		tutorial_layer.connect("tutorial_finished", _on_tutorial_finished)

	# 🔥 Delegamos toda la lógica al propio tutorial
	if tutorial_layer.has_method("setup"):
		tutorial_layer.setup(_dg())

# ─────────────────────────────────────────────
# LOOP
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _room_timer_paused:
		if tutorial_layer == null or not is_instance_valid(tutorial_layer):
			_room_timer_paused = false
		else:
			if hud and room_timer:
				var status := room_timer.get_status()
				hud.update_room_timer(
					status["remaining"],
					Main2dRoomTimer.ROOM_TIMER_SECONDS,
					status["color"]
				)
			return

	var tick_data := room_timer.tick(delta)

	if hud:
		hud.update_room_timer(
			tick_data["remaining"],
			Main2dRoomTimer.ROOM_TIMER_SECONDS,
			tick_data["color"]
		)

	if tick_data["expired"]:
		push_warning("Room timer reached zero - triggering death state")
		_on_player_died()

func _input(event: InputEvent) -> void:
	if tutorial_layer and is_instance_valid(tutorial_layer) and tutorial_layer.visible:
		return
	if event.is_action_pressed("ui_cancel") and not _is_dead:
		_set_paused_state(not get_tree().paused)
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────
# GAME EVENTS
# ─────────────────────────────────────────────
func _on_room_changed(room_id: int) -> void:
	if room_id not in visited_rooms:
		visited_rooms.append(room_id)
		_reset_room_timer()

	if hud:
		hud.update_current_room(room_id)

	if hud and enemy_manager:
		hud.update_enemies_remaining(enemy_manager.get_enemies_in_room(room_id))

func _on_room_cleared(_room_id: int) -> void:
	rooms_cleared += 1
	print("[ROOM_CLEARED] Room %d cleared, _victory_triggered=%s" % [_room_id, _victory_triggered])

	# If victory already triggered (boss died), skip reward flow
	if _victory_triggered:
		print("[ROOM_CLEARED] Victory already triggered, skipping rewards")
		return

	if _is_dead:
		return

	# Guard: Skip reward generation if we're in the boss/final room
	# (room_cleared may fire before _on_boss_defeated sets _victory_triggered)
	if enemy_manager and _room_id == enemy_manager.final_room_id:
		print("[ROOM_CLEARED] Boss room cleared, but _victory_triggered not yet set. Skipping rewards.")
		return

	if card_reward_manager and game_state_manager and game_state_manager.is_active():
		# Prevent overlapping reward requests
		if _reward_pending:
			print("[ROOM_CLEARED] Reward already pending, skipping duplicate request")
			return

		var reward_cards: Array[CardData] = card_reward_manager.generate_reward_options(3)
		if reward_cards.is_empty():
			return

		# If this is the final room (boss), request reward immediately is guarded above;
		# otherwise delay slightly for pacing. Capture room id locally for the await scope.
		var captured_room_id: int = _room_id
		_reward_pending = true
		# If this room is the final room id and victory might be triggered, skip delay
		if enemy_manager and captured_room_id == enemy_manager.final_room_id:
			print("[ROOM_CLEARED] Final room cleared — requesting reward immediately")
			game_state_manager.request_reward(reward_cards)
			return

		# Non-boss delay to improve pacing. Re-check guards after the delay.
		print("[ROOM_CLEARED] Delaying reward by 1.0s for pacing")
		await get_tree().create_timer(1.0).timeout

		# Post-delay validation: abort if victory/death triggered or game state not active
		if _victory_triggered or _is_dead:
			print("[ROOM_CLEARED] Post-delay abort: victory or death detected")
			_reward_pending = false
			return

		if enemy_manager and enemy_manager.get_enemies_in_room(captured_room_id) > 0:
			print("[ROOM_CLEARED] Post-delay abort: enemies reappeared in room %d" % captured_room_id)
			_reward_pending = false
			return

		if game_state_manager and game_state_manager.is_active():
			print("[ROOM_CLEARED] Requesting reward with %d cards" % reward_cards.size())
			game_state_manager.request_reward(reward_cards)
		else:
			print("[ROOM_CLEARED] Post-delay abort: game state not active")
			_reward_pending = false

func _on_enemy_defeated() -> void:
	enemies_killed += 1

	var dg = _dg()
	if hud and dg and enemy_manager:
		hud.update_enemies_remaining(
			enemy_manager.get_enemies_in_room(dg.active_room_id)
		)

func _on_player_died() -> void:
	if _is_dead:
		return
	
	_is_dead = true
	if victory_overlay:
		victory_overlay.hide_victory()
	
	# Grant accumulated gold from defeated enemies before showing death screen
	if enemy_manager:
		enemy_manager.grant_and_reset_accumulated_gold()
	
	# Use GameStateManager to handle death state
	var gsm := _get_game_state_manager()
	if gsm:
		gsm.request_death()
	else:
		# Fallback to old method
		if map_manager and map_manager.turn_manager:
			map_manager.turn_manager.stop()
		if pause_menu and pause_menu.has_method("close_menu"):
			pause_menu.close_menu()
		get_tree().paused = true
	
	# Show death overlay
	# Compute run-earned gold (do not double-add gold here)
	var currency := get_node_or_null("/root/CurrencyManager") as CurrencyManager
	var run_gold := 0
	if currency:
		run_gold = max(0, int(currency.get_gold() - _run_gold_start))

	if death_handler:
		death_handler.handle_player_died(enemies_killed, rooms_cleared, run_gold)

func _on_boss_defeated(enemy) -> void:
	if _victory_triggered:
		return
	# Rely on the explicit `is_boss` flag rather than fragile name prefixes
	if enemy == null or enemy.get("is_boss") != true:
		return

	_victory_triggered = true  # Set FIRST to guard against room_cleared signal

	if death_overlay:
		death_overlay.visible = false

	var gsm := _get_game_state_manager()
	if gsm:
		gsm.request_victory()
	else:
		_on_victory_entered()

	# Clear any pending reward flags to avoid accidental reward UIs
	_reward_pending = false


func _on_victory_entered() -> void:
	var tree := get_tree()
	if tree == null:
		return
	
	# Grant accumulated gold from defeated enemies before showing victory screen
	if enemy_manager:
		enemy_manager.grant_and_reset_accumulated_gold()
	
	var currency := get_node_or_null("/root/CurrencyManager") as CurrencyManager
	var run_gold := 0
	if currency:
		run_gold = max(0, int(currency.get_gold() - _run_gold_start))

		# Removed SceneTree metadata writes. VictoryOverlay is authoritative and
		# will be shown directly via `show_victory(...)`.

	if victory_overlay:
		victory_overlay.show_victory(enemies_killed, rooms_cleared, run_gold)
	else:
		push_error("[MAIN_2D] Victory overlay node is missing from Main2D.tscn")


# ─────────────────────────────────────────────
# PAUSE
# ─────────────────────────────────────────────
func _set_paused_state(paused: bool) -> void:
	if pause_menu:
		if paused and pause_menu.has_method("open_menu"):
			pause_menu.open_menu()
		elif not paused and pause_menu.has_method("close_menu"):
			pause_menu.close_menu()

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_pause_exit_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ─────────────────────────────────────────────
# TIMER
# ─────────────────────────────────────────────
func _reset_room_timer() -> void:
	if room_timer:
		room_timer.reset()

func _on_tutorial_started() -> void:
	_room_timer_paused = true
	var gsm := _get_game_state_manager()
	if gsm:
		gsm.request_pause()

func _on_tutorial_finished() -> void:
	_room_timer_paused = false
	var gsm := _get_game_state_manager()
	if gsm:
		gsm.request_resume()

func _get_game_state_manager() -> GameStateManager:
	return get_tree().get_first_node_in_group("game_state_manager") as GameStateManager

# ─────────────────────────────────────────────
# REWARD HANDLERS
# ─────────────────────────────────────────────
func _on_reward_completed(_selected_card: CardData) -> void:
	# Reward completed, return to active state via GameStateManager
	print("[MAIN_2D] _on_reward_completed called with card: %s" % (_selected_card.display_name if _selected_card else "null"))
	if game_state_manager:
		print("[MAIN_2D] Calling game_state_manager.close_reward()")
		game_state_manager.close_reward(_selected_card)
	else:
		print("[MAIN_2D] ERROR: game_state_manager is null!")
	_update_hotbar_display()
	print("[MAIN_2D] Hotbar display updated")

func _update_hotbar_display() -> void:
	if map_manager:
		var player := map_manager.get_node_or_null("Player") as PlayerMovement
		if player:
			var controller := player.get_node_or_null("PlayerActionController") as PlayerActionController
			if controller == null:
				return

			# Refresh through the actual CardSystemController location:
			# Player -> PlayerActionController -> CardSystemController
			if controller.card_system_controller and controller.card_system_controller.has_method("update_hotbar_ui"):
				print("[MAIN_2D] _update_hotbar_display: refreshing hotbar UI only (no targeting clear)")
				controller.card_system_controller.update_hotbar_ui()

func _on_reward_entered(cards: Array) -> void:
	if hud:
		var requires_replace := false
		var equipped_slots: Array = []
		if card_reward_manager:
			requires_replace = card_reward_manager.is_hotbar_full()
			equipped_slots = card_reward_manager.get_equipped_cards_for_replace()
		hud.show_reward_selection(cards, requires_replace, equipped_slots)

func _on_reward_exited(_selected_card: CardData) -> void:
	if hud:
		hud.hide_reward_selection()
	# Clear pending flag so future rewards can be requested
	_reward_pending = false

func _on_reward_card_selected(selected_card: CardData) -> void:
	if card_reward_manager == null:
		return
	card_reward_manager.apply_selected_reward(selected_card)

func _on_reward_card_replace_selected(selected_card: CardData, slot_index: int) -> void:
	if card_reward_manager == null:
		return
	card_reward_manager.apply_selected_reward(selected_card, slot_index)

func _on_reward_skipped() -> void:
	if card_reward_manager == null:
		return
	card_reward_manager.skip_reward()
