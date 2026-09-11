extends Node2D

# Main2d: scene-level orchestrator for the gameplay scene.
# Responsibilities:
# - Instantiate and wire managers (GameStateManager, CardRewardManager, etc.)
# - Connect UI (HUD / overlays) to gameplay signals and mediate reward/death flows.
# - Act as the canonical owner for room/timer, enemy manager and top-level
#   presentation concerns. Avoid adding gameplay logic here; prefer managers.

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

var tutorial_layer: TutorialLayer = null
var _run_gold_start: int = 0
var _reward_pending: bool = false
var post_victory_popup: PostVictoryPopup = null

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
	_load_post_victory_popup_if_needed()

	_reset_room_timer()

	# Capture starting gold for this run to compute run-earned gold later
	var currency := ManagerLocator.get_currency_manager() as CurrencyManager
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
	var player_stats = ManagerLocator.get_player_stats()

	if player_stats and not player_stats.player_died.is_connected(Callable(self, "_on_player_died")):
		player_stats.player_died.connect(Callable(self, "_on_player_died"))

func _connect_ui() -> void:
	_connect_menu_ui()
	_connect_victory_ui()
	_connect_reward_ui()
	_connect_state_ui()
	_connect_hud_card_system_binding()

## Connects pause menu controls to the top-level scene flow.
func _connect_menu_ui() -> void:
	if retry_button and not retry_button.pressed.is_connected(Callable(self, "_on_retry_pressed")):
		retry_button.pressed.connect(Callable(self, "_on_retry_pressed"))

	if exit_button and not exit_button.pressed.is_connected(Callable(self, "_on_return_pressed")):
		exit_button.pressed.connect(Callable(self, "_on_return_pressed"))

	if pause_menu:
		pause_menu.close()

	if pause_menu and not pause_menu.exit_requested.is_connected(Callable(self, "_on_pause_exit_requested")):
		pause_menu.exit_requested.connect(Callable(self, "_on_pause_exit_requested"))


## Connects the victory overlay actions without mixing them into pause menu setup.
func _connect_victory_ui() -> void:
	if victory_overlay == null:
		return

	if not victory_overlay.retry_requested.is_connected(Callable(self, "_on_retry_pressed")):
		victory_overlay.retry_requested.connect(Callable(self, "_on_retry_pressed"))
	if not victory_overlay.exit_requested.is_connected(Callable(self, "_on_return_pressed")):
		victory_overlay.exit_requested.connect(Callable(self, "_on_return_pressed"))


## Bridges reward UI events from the HUD into Main2d orchestration.
func _connect_reward_ui() -> void:
	if hud == null or hud.card_reward_ui == null:
		return
	var reward_ui := hud.card_reward_ui
	if not reward_ui.card_selected.is_connected(Callable(self, "_on_reward_card_selected")):
		reward_ui.card_selected.connect(Callable(self, "_on_reward_card_selected"))
	if not reward_ui.reward_skipped.is_connected(Callable(self, "_on_reward_skipped")):
		reward_ui.reward_skipped.connect(Callable(self, "_on_reward_skipped"))
	if not reward_ui.card_replace_selected.is_connected(Callable(self, "_on_reward_card_replace_selected")):
		reward_ui.card_replace_selected.connect(Callable(self, "_on_reward_card_replace_selected"))


## Connects state machine transitions that Main2d reacts to directly.
func _connect_state_ui() -> void:
	if game_state_manager and not game_state_manager.reward_entered.is_connected(Callable(self, "_on_reward_entered")):
		game_state_manager.reward_entered.connect(Callable(self, "_on_reward_entered"))
	if game_state_manager and not game_state_manager.reward_exited.is_connected(Callable(self, "_on_reward_exited")):
		game_state_manager.reward_exited.connect(Callable(self, "_on_reward_exited"))
	if game_state_manager and not game_state_manager.victory_entered.is_connected(Callable(self, "_on_victory_entered")):
		game_state_manager.victory_entered.connect(Callable(self, "_on_victory_entered"))


## Defers HUD/card-system binding until both sides are in the tree.
func _connect_hud_card_system_binding() -> void:
	var player_node := map_manager.get_node_or_null("Player") as PlayerMovement
	if player_node and hud:
		var action_controller := player_node.get_node_or_null("PlayerActionController") as PlayerActionController
		if action_controller and action_controller.card_system_controller:
			hud.hud_ready.connect(action_controller.card_system_controller.bind_hud_external.bind(hud))

# ─────────────────────────────────────────────
# TUTORIAL 
# ─────────────────────────────────────────────
func _load_tutorial_if_needed() -> void:
	var save_mgr = ManagerLocator.get_save_manager()
	if not save_mgr or not save_mgr.first_time_player:
		return

	var scene := load("res://scenes/TutorialLayer.tscn")
	if not scene:
		return

	tutorial_layer = scene.instantiate() as TutorialLayer
	add_child(tutorial_layer)
	_room_timer_paused = true

	if not tutorial_layer.tutorial_started.is_connected(_on_tutorial_started):
		tutorial_layer.tutorial_started.connect(_on_tutorial_started)
	if not tutorial_layer.tutorial_finished.is_connected(_on_tutorial_finished):
		tutorial_layer.tutorial_finished.connect(_on_tutorial_finished)

# ─────────────────────────────────────────────
# LOOP
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	if not game_state_manager or not game_state_manager.is_active():
		return
	if _room_timer_paused:
		if tutorial_layer == null or not is_instance_valid(tutorial_layer):
			_room_timer_paused = false
		else:
			_update_room_timer_ui(room_timer.get_status())
			return

	var tick_data := room_timer.tick(delta)
	_update_room_timer_ui(tick_data)

	if tick_data["expired"]:
		push_warning("Room timer reached zero - triggering death state")
		_room_timer_paused = true
		_trigger_timeout_death_flow()

func _trigger_timeout_death_flow() -> void:
	var player_node := get_tree().get_first_node_in_group("player") as PlayerMovement
	if player_node and player_node.has_method("trigger_time_out_death"):
		player_node.trigger_time_out_death()
	
	await get_tree().create_timer(1.2).timeout
	_on_player_died()

func _input(event: InputEvent) -> void:
	if tutorial_layer and is_instance_valid(tutorial_layer) and tutorial_layer.visible:
		return
	if event.is_action_pressed("ui_cancel") and not _is_dead:
		var can_toggle_pause := pause_menu != null \
			and (pause_menu.is_open or (game_state_manager and game_state_manager.is_active()))
		if can_toggle_pause:
			pause_menu.toggle()
		get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────
# GAME EVENTS
# ─────────────────────────────────────────────
func _on_room_changed(room_id: int) -> void:
	if _should_reset_room_timer(room_id):
		_reset_room_timer()

	if room_id not in visited_rooms:
		visited_rooms.append(room_id)

	if hud:
		hud.update_current_room(room_id)

	if hud and enemy_manager:
		hud.update_enemies_remaining(enemy_manager.get_enemies_in_room(room_id))

func _should_reset_room_timer(room_id: int) -> bool:
	if room_id < 0:
		return false
	if room_id in visited_rooms:
		return false
	if enemy_manager == null:
		return false
	return enemy_manager.get_enemies_in_room(room_id) > 0

func _on_room_cleared(_room_id: int) -> void:
	rooms_cleared += 1

	if _victory_triggered:
		return

	if _is_dead:
		return

	var is_boss_room := false
	var dg = _dg()
	if dg:
		var info := dg.get_room_info(_room_id)
		if not info.is_empty() and info.get("template", "") == "boss":
			is_boss_room = true

	if enemy_manager and is_boss_room:
		return

	if card_reward_manager and game_state_manager and game_state_manager.is_active():
		var reward_cards: Array[CardData] = card_reward_manager.generate_reward_options(3)
		if reward_cards.is_empty():
			return
		_request_room_reward(_room_id, reward_cards)

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
	_hide_victory_overlay()
	
	if enemy_manager:
		enemy_manager.grant_and_reset_accumulated_gold()
	
	if game_state_manager:
		game_state_manager.request_death()
	else:
		if map_manager and map_manager.turn_manager:
			map_manager.turn_manager.stop()
		if pause_menu:
			pause_menu.close()
		get_tree().paused = true
	
	var run_gold := _get_run_gold_earned()

	if death_handler:
		death_handler.show_death_screen(enemies_killed, rooms_cleared, run_gold)

func _on_boss_defeated(enemy) -> void:
	if _victory_triggered:
		return
	if enemy == null or enemy.get("is_boss") != true:
		return

	_victory_triggered = true

	if death_overlay:
		death_overlay.visible = false
	_hide_victory_overlay()

	if game_state_manager:
		game_state_manager.request_victory()
	else:
		_on_victory_entered()

	_reward_pending = false


func _on_victory_entered() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.increment_run_cycle()
		save_mgr.post_victory_popup_pending = true
	
	if enemy_manager:
		enemy_manager.grant_and_reset_accumulated_gold()
	
	_show_victory_overlay(_get_run_gold_earned())

func _update_room_timer_ui(status: Dictionary) -> void:
	if hud == null or room_timer == null or status == null:
		return
	hud.update_room_timer(
		status.get("remaining", 0.0),
		Main2dRoomTimer.ROOM_TIMER_SECONDS,
		status.get("color", Color.WHITE)
	)

func _request_room_reward(room_id: int, reward_cards: Array[CardData]) -> void:
	if _reward_pending:
		return

	_reward_pending = true
	var is_boss_room := false
	var dg = _dg()
	if dg:
		var info := dg.get_room_info(room_id)
		if not info.is_empty() and info.get("template", "") == "boss":
			is_boss_room = true

	if enemy_manager and is_boss_room:
		game_state_manager.request_reward(reward_cards)
		return

	_request_room_reward_after_delay(room_id, reward_cards)

func _request_room_reward_after_delay(room_id: int, reward_cards: Array[CardData]) -> void:
	await get_tree().create_timer(1.0).timeout

	if _victory_triggered or _is_dead:
		_clear_reward_pending()
		return

	if enemy_manager and enemy_manager.get_enemies_in_room(room_id) > 0:
		_clear_reward_pending()
		return

	if game_state_manager and game_state_manager.is_active():
		game_state_manager.request_reward(reward_cards)
	else:
		_clear_reward_pending()

func _on_reward_completed(selected_card: CardData) -> void:
	if game_state_manager:
		game_state_manager.close_reward(selected_card)

func _get_run_gold_earned() -> int:
	var currency := ManagerLocator.get_currency_manager() as CurrencyManager
	if currency:
		return max(0, int(currency.get_gold() - _run_gold_start))
	return 0

func _show_victory_overlay(run_gold: int) -> void:
	if victory_overlay:
		victory_overlay.show_victory(enemies_killed, rooms_cleared, run_gold)

func _hide_victory_overlay() -> void:
	if victory_overlay:
		victory_overlay.hide_victory()

# ─────────────────────────────────────────────
# PAUSE
# ─────────────────────────────────────────────
func _on_return_pressed() -> void:
	_go_to_main_menu()

func _on_pause_exit_requested() -> void:
	_go_to_main_menu()

func _on_retry_pressed() -> void:
	_reload_current_scene()

func _go_to_main_menu() -> void:
	_cleanup_and_change_scene("res://scenes/MainMenu.tscn")

func _reload_current_scene() -> void:
	_cleanup_and_change_scene("", true)

func _cleanup_and_change_scene(target_scene: String, reload: bool = false) -> void:
	ManagerLocator.flush_saves()
	get_tree().paused = false
	if reload:
		get_tree().reload_current_scene()
	elif not target_scene.is_empty():
		get_tree().change_scene_to_file(target_scene)

# ─────────────────────────────────────────────
# TIMER
# ─────────────────────────────────────────────
func _reset_room_timer() -> void:
	if room_timer:
		room_timer.reset()

func _on_tutorial_started() -> void:
	_room_timer_paused = true
	if game_state_manager:
		game_state_manager.request_pause()

func _on_tutorial_finished() -> void:
	var popup_shown := _load_post_victory_popup_if_needed()
	_room_timer_paused = popup_shown
	if game_state_manager and not popup_shown:
		game_state_manager.request_resume()

func _get_game_state_manager() -> GameStateManager:
	return game_state_manager

func _on_reward_entered(cards: Array) -> void:
	if hud:
		var requires_replace := false
		var equipped_slots: Array = []
		if card_reward_manager:
			requires_replace = card_reward_manager.is_hotbar_full()
			equipped_slots = card_reward_manager.get_equipped_cards_for_replace()
		if hud.card_reward_ui:
			hud.card_reward_ui.show_reward(cards, requires_replace, equipped_slots)

func _on_reward_exited(_selected_card: CardData) -> void:
	if hud and hud.card_reward_ui:
		hud.card_reward_ui.hide_reward()
	_clear_reward_pending()

func _on_reward_card_selected(selected_card: CardData) -> void:
	_apply_selected_reward(selected_card)

func _on_reward_card_replace_selected(selected_card: CardData, slot_index: int) -> void:
	_apply_selected_reward(selected_card, slot_index)

func _apply_selected_reward(selected_card: CardData, slot_index: int = -1) -> void:
	if card_reward_manager == null:
		return
	card_reward_manager.apply_selected_reward(selected_card, slot_index)

func _on_reward_skipped() -> void:
	if card_reward_manager == null:
		return
	card_reward_manager.skip_reward()

func _clear_reward_pending() -> void:
	_reward_pending = false

func _load_post_victory_popup_if_needed() -> bool:
	if post_victory_popup and is_instance_valid(post_victory_popup):
		return true

	if tutorial_layer and is_instance_valid(tutorial_layer) and tutorial_layer.visible:
		return false

	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr == null:
		return false
	if not save_mgr.post_victory_popup_pending:
		return false
	if save_mgr.get_run_cycle() <= 0:
		return false

	var scene := load("res://scenes/PostVictoryPopup.tscn")
	if scene == null:
		return false

	var popup_instance := scene.instantiate() as PostVictoryPopup
	if popup_instance == null:
		return false

	post_victory_popup = popup_instance
	post_victory_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	if not post_victory_popup.continue_pressed.is_connected(Callable(self, "_on_post_victory_popup_continue_pressed")):
		post_victory_popup.continue_pressed.connect(Callable(self, "_on_post_victory_popup_continue_pressed"))

	add_child(post_victory_popup)
	post_victory_popup.show_popup(save_mgr.get_run_cycle())

	_room_timer_paused = true
	if game_state_manager:
		game_state_manager.request_pause()

	return true

func _on_post_victory_popup_continue_pressed() -> void:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.post_victory_popup_pending = false
		save_mgr.save_game()

	if post_victory_popup and is_instance_valid(post_victory_popup):
		post_victory_popup.queue_free()
	post_victory_popup = null

	_room_timer_paused = false
	if game_state_manager:
		game_state_manager.request_resume()
