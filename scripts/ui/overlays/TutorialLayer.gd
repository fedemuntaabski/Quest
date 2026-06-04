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
# CONFIG STEPS
# =====================================================

var steps: Array[TutorialStep] = [
	TutorialStep.new(
		"Bienvenido a la mazmorra, cazarecompensas. Para sobrevivir a este contrato y reclamar tu oro. Recuerda: en QUEST, cada movimiento es una decisión de vida o muerte.",
		true
	),
	TutorialStep.new(
		"La mazmorra se rige por turnos. Verás un resaltador de casillas en el suelo: las casillas válidas para moverte se iluminarán al pasar el mouse. Haz clic izquierdo en una de ellas para desplazarte. Ten cuidado: cada paso consume un turno, lo que permite que los enemigos también actúen",
		true
	),
	TutorialStep.new(
		"No temas a la oscuridad. A medida que avanzas por las habitaciones modulares, la cámara se ajustará automáticamente para seguir tu posición, manteniéndote siempre en el centro de la acción dentro de la sala actual.",
		true
	),
	TutorialStep.new(
		"Cuando veas una criatura, no te lances a ciegas. Acércate lo suficiente y, cuando el enemigo esté dentro del rango de tu arma o habilidad, haz clic sobre él para iniciar el ataque. El éxito dependerá de tus estadísticas y de la suerte del dado 1d6."
	),
	TutorialStep.new(
		"Cuentas con un mazo de hasta 3 cartas activas que puedes alternar con las teclas [1], [2] y [3]. Al eliminar a los enemigos de la sala, podrás elegir una carta nueva. Si ya tienes 3 cartas equipadas, el juego te permitirá reemplazar una de las actuales por la nueva o, si prefieres mantener tu equipo actual, puedes skipearla"
	),
	TutorialStep.new(
		"Al derrotar enemigos, estos soltarán oro que acumularás durante tu incursión. Sin embargo, este botín solo se entregará a tu inventario permanente al finalizar la partida (ya sea ganando o muriendo). Solo en ese momento podrás canjearlo en el menú para mejorar tus estadísticas."
	),
	TutorialStep.new(
		"Mantén un ojo en la interfaz superior. Allí verás tus puntos de vida (HP), estadísticas (Fuerza, Magia, Agilidad) y la poción de vida. Si tu vida baja, usa tu poción de unico	uso para recuperar el 50% de tu salud maxima."
	),
	TutorialStep.new(
		"Es obligatorio eliminar a todos los enemigos para que las puertas se abran y puedas avanzar. Pero no te demores: si el cronómetro de la sala llega a cero, la mazmorra te devorará, resultando en una muerte instantánea."
	),
	TutorialStep.new(
		"Tu objetivo es superar 8 salas. Explora y gestiona tu tiempo. Al final del camino, el Enemigo Final aparecerá en la ultima sala; encuéntralo y derrótalo para cerrar el contrato y arrancar con uno nuevo, si te animas."
	)
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
var tween: Tween

# =====================================================
# UI REFS
# =====================================================

@onready var dimmer: ColorRect = $Dimer

@onready var tutorial_panel: PanelContainer = \
	$RootControl/MarginContainer/TutorialPanel

@onready var title_label: Label = \
	$RootControl/MarginContainer/TutorialPanel/Content/TitleLabel

@onready var body_label: Label = \
	$RootControl/MarginContainer/TutorialPanel/Content/BodyLabel

@onready var hint_label: Label = \
	$RootControl/MarginContainer/TutorialPanel/Content/HintLabel


# =====================================================
# SETUP
# =====================================================

func setup(dg: DungeonGenerator) -> void:
	dungeon_generator = dg

	if dungeon_generator \
	and not dungeon_generator.room_cleared.is_connected(_on_room_cleared):

		dungeon_generator.room_cleared.connect(
			_on_room_cleared
		)


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

	if event.is_action_pressed("ui_accept"):
		advance_step()
		return

	if event is InputEventMouseButton \
	and event.pressed:

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

	title_label.text = "Tutorial"
	body_label.text = step.text
	hint_label.text = "[Click o Enter para continuar]"

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

	tutorial_panel.modulate.a = 0.0
	dimmer.modulate.a = 0.0

	tween.tween_property(
		tutorial_panel,
		"modulate:a",
		1.0,
		0.25
	)

	tween.tween_property(
		dimmer,
		"modulate:a",
		0.35,
		0.25
	)


func play_fade_out() -> void:

	if tween:
		tween.kill()

	tween = create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	tween.tween_property(
		tutorial_panel,
		"modulate:a",
		0.0,
		0.20
	)

	tween.tween_property(
		dimmer,
		"modulate:a",
		0.0,
		0.20
	)


# =====================================================
# GAME EVENTS
# =====================================================

func _on_room_cleared(_room_id: int) -> void:
	finish_tutorial()


# =====================================================
# FINISH
# =====================================================

func finish_tutorial() -> void:

	if state == State.FINISHED:
		return

	state = State.FINISHED

	visible = false

	tutorial_finished.emit()

	var save_mgr = ManagerLocator.get_save_manager()

	if save_mgr:
		save_mgr.first_time_player = false
		save_mgr.save_game()

	queue_free()
