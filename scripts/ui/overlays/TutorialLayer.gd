extends CanvasLayer
class_name TutorialLayer

# =====================================================
# SIGNALS
# =====================================================

signal tutorial_started
signal tutorial_finished

# =====================================================
# STEP MODEL
# =====================================================

class TutorialStep:
	var text: String
	var wait_for_action: bool = false
	var auto_advance: bool = false

	func _init(_text: String, _wait_for_action := false, _auto := false):
		text = _text
		wait_for_action = _wait_for_action
		auto_advance = _auto


# =====================================================
# CONFIG STEPS (DATA-DRIVEN)
# =====================================================

var steps: Array[TutorialStep] = [
	TutorialStep.new("Paso 1/8 - Movimiento: haz click en una casilla válida para moverte por la mazmorra. El movimiento consume un turno.", true),
	TutorialStep.new("Paso 2/8 - Cámara y exploración: avanza por las habitaciones. La cámara sigue tu posición dentro de la sala actual."),
	TutorialStep.new("Paso 3/8 - Combate básico: acércate a un enemigo y haz click cuando estés en rango."),
	TutorialStep.new("Paso 4/8 - Sistema de cartas: usa teclas 1, 2 y 3 para cambiar carta activa."),
	TutorialStep.new("Paso 5/8 - Estados: efectos como stun, bleed, burn o poison alteran el combate."),
	TutorialStep.new("Paso 6/8 - Recursos: los enemigos pueden soltar oro para mejoras."),
	TutorialStep.new("Paso 7/8 - HUD: vida, stats y estados visibles siempre en interfaz superior."),
	TutorialStep.new("Paso 8/8 - Progresión: limpia habitaciones para avanzar al jefe final.")
]

# =====================================================
# STATE
# =====================================================

enum State {
	IDLE,
	SHOWING,
	TRANSITIONING,
	FINISHED
}

var state: State = State.IDLE
var step_index: int = 0

var dungeon_generator: DungeonGenerator = null

# =====================================================
# UI REFS
# =====================================================

@onready var label: Label = $Label
@onready var bg: ColorRect = $ColorRect

# =====================================================
# TWEEN
# =====================================================

var tween: Tween

# =====================================================
# SETUP
# =====================================================

func setup(dg: DungeonGenerator) -> void:
	dungeon_generator = dg

	if dungeon_generator and not dungeon_generator.room_cleared.is_connected(_on_room_cleared):
		dungeon_generator.room_cleared.connect(_on_room_cleared)


# =====================================================
# READY
# =====================================================

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var save_mgr = ManagerLocator.get_save_manager()
	if save_mgr and save_mgr.first_time_player:
		call_deferred("_start_tutorial")
	else:
		queue_free()


# =====================================================
# INPUT
# =====================================================

func _input(event: InputEvent) -> void:
	if state != State.SHOWING:
		return

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		advance_step()


# =====================================================
# FLOW
# =====================================================

func _start_tutorial() -> void:
	state = State.SHOWING
	visible = true

	tutorial_started.emit()
	show_step()


func show_step() -> void:
	if step_index >= steps.size():
		finish_tutorial()
		return

	var step := steps[step_index]

	label.text = step.text + "\n\n[Click o Enter para continuar]"
	play_fade_in()


# =====================================================
# ADVANCE
# =====================================================

func advance_step() -> void:
	if state != State.SHOWING:
		return

	state = State.TRANSITIONING
	play_fade_out()

	await tween.finished

	step_index += 1
	state = State.SHOWING
	show_step()


# =====================================================
# ANIMATION
# =====================================================

func play_fade_in() -> void:
	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(label, "modulate:a", 1.0, 0.25).from(0.0)
	tween.tween_property(bg, "modulate:a", 0.6, 0.25).from(0.0)


func play_fade_out() -> void:
	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(label, "modulate:a", 0.0, 0.2)
	tween.tween_property(bg, "modulate:a", 0.0, 0.2)


# =====================================================
# GAME EVENTS
# =====================================================

func _on_room_cleared(_room_id: int) -> void:
	# El tutorial puede decidir abortar según diseño
	finish_tutorial()


# =====================================================
# FINISH
# =====================================================

func finish_tutorial() -> void:
	state = State.FINISHED
	visible = false

	tutorial_finished.emit()

	var save_mgr = ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.first_time_player = false
		save_mgr.save_game()

	queue_free()