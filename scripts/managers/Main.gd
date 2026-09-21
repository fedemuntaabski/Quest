extends Node
class_name Main

## Main: root scene orchestrator. Owns WorldContainer (Main2d.tscn),
## UIContainer (MainMenu/WaitingRoom.tscn), HUDContainer (HUD.tscn) and a
## TransitionOverlay fade. Replaces ad-hoc get_tree().change_scene_to_file()
## calls so gameplay/menu subscenes can be swapped without reloading the
## whole tree (autoloads, main_orchestrator group lookup, etc. stay alive).

const MAIN_MENU_SCENE := preload("res://scenes/MainMenu.tscn")
const WAITING_ROOM_SCENE := preload("res://scenes/WaitingRoom.tscn")
const MAIN2D_SCENE := preload("res://scenes/Main2d.tscn")
const HUD_SCENE := preload("res://scenes/HUD.tscn")

const FADE_DURATION := 0.25

@onready var world_container: Node2D = $WorldContainer
@onready var ui_container: CanvasLayer = $UIContainer
@onready var hud_container: Node = $HUDContainer
@onready var transition_rect: ColorRect = $TransitionOverlay/ColorRect

var _is_transitioning: bool = false


func _ready() -> void:
	add_to_group("main_orchestrator")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_content_scaling()
	show_main_menu()


func _setup_content_scaling() -> void:
	var root_window: Window = get_tree().root
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP


# ─────────────────────────────────────────────
# PUBLIC ORCHESTRATION API
# ─────────────────────────────────────────────
func show_main_menu() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	await _fade_to_black()
	await _clear_containers(true, true, true)
	_current_ui_add(MAIN_MENU_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


func return_to_main_menu() -> void:
	if _is_transitioning:
		return
	ManagerLocator.flush_saves()
	get_tree().paused = false
	await show_main_menu()


func start_gameplay() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	await _fade_to_black()
	await _clear_containers(true, true, true)
	_current_world_add(MAIN2D_SCENE.instantiate())
	_current_hud_add(HUD_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


func go_to_waiting_room() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	await _fade_to_black()
	await _clear_containers(true, true, true)
	_current_ui_add(WAITING_ROOM_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


func reload_gameplay() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	ManagerLocator.flush_saves()
	get_tree().paused = false

	await _fade_to_black()
	await _clear_containers(true, false, true)
	_current_world_add(MAIN2D_SCENE.instantiate())
	_current_hud_add(HUD_SCENE.instantiate())
	await _fade_from_black()

	_is_transitioning = false


# ─────────────────────────────────────────────
# INTERNAL HELPERS
# ─────────────────────────────────────────────
func _current_world_add(node: Node) -> void:
	world_container.add_child(node)


func _current_ui_add(node: Node) -> void:
	ui_container.add_child(node)


func _current_hud_add(node: Node) -> void:
	hud_container.add_child(node)


func _fade_to_black(duration: float = FADE_DURATION) -> void:
	var tw := MenuTransitionFX.play_entrance(self,
		[{"node": transition_rect, "max_alpha": 1.0}], [], duration,
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2.ONE)
	if tw:
		await tw.finished


func _fade_from_black(duration: float = FADE_DURATION) -> void:
	var tw := MenuTransitionFX.play_exit(self,
		[{"node": transition_rect, "max_alpha": 1.0}], [], duration, Vector2.ONE,
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	if tw:
		await tw.finished


func _clear_containers(clear_world: bool, clear_ui: bool, clear_hud: bool) -> void:
	if clear_world:
		for c in world_container.get_children():
			c.queue_free()
	if clear_ui:
		for c in ui_container.get_children():
			c.queue_free()
	if clear_hud:
		for c in hud_container.get_children():
			c.queue_free()
	if clear_world or clear_ui or clear_hud:
		await get_tree().process_frame
