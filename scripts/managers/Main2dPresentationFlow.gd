extends RefCounted
class_name Main2dPresentationFlow

var hud: HUDController = null
var pause_menu: PauseMenu = null
var victory_overlay: VictoryOverlay = null

func setup(p_hud: HUDController, p_pause_menu: PauseMenu, p_victory_overlay: VictoryOverlay) -> void:
	hud = p_hud
	pause_menu = p_pause_menu
	victory_overlay = p_victory_overlay

func set_paused_state(paused: bool) -> void:
	if pause_menu == null:
		return

	if paused and pause_menu.has_method("open_menu"):
		pause_menu.open_menu()
	elif not paused and pause_menu.has_method("close_menu"):
		pause_menu.close_menu()

func show_reward_selection(cards: Array, reward_manager: CardRewardManager) -> void:
	if hud == null:
		return

	var requires_replace := false
	var equipped_slots: Array = []
	if reward_manager:
		requires_replace = reward_manager.is_hotbar_full()
		equipped_slots = reward_manager.get_equipped_cards_for_replace()
	hud.show_reward_selection(cards, requires_replace, equipped_slots)

func hide_reward_selection() -> void:
	if hud:
		hud.hide_reward_selection()

func show_victory_overlay(enemies_killed: int, rooms_cleared: int, run_gold: int) -> void:
	if victory_overlay:
		victory_overlay.show_victory(enemies_killed, rooms_cleared, run_gold)
	else:
		push_error("[MAIN_2D] Victory overlay node is missing from Main2D.tscn")

func hide_victory_overlay() -> void:
	if victory_overlay:
		victory_overlay.hide_victory()