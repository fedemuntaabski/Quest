extends BaseMenu
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

	func _init(_text: String):
		text = _text


# =====================================================
# CONFIG STEPS
# =====================================================

var steps: Array[TutorialStep] = [
	TutorialStep.new(
		"Bienvenido a la mazmorra, cazarecompensas. Para sobrevivir a este contrato y reclamar tu oro. Recuerda: en QUEST, cada movimiento es una decisión de vida o muerte."
	),
	TutorialStep.new(
		"La mazmorra se rige por turnos. Verás un resaltador de casillas en el suelo: las casillas válidas para moverte se iluminarán al pasar el mouse. Haz clic izquierdo en una de ellas para desplazarte. Ten cuidado: cada paso consume un turno, lo que permite que los enemigos también actúen"
	),
	TutorialStep.new(
		"No temas a la oscuridad. A medida que avanzas por las habitaciones modulares, la cámara se ajustará automáticamente para seguir tu posición, manteniéndote siempre en el centro de la acción dentro de la sala actual."
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

# =====================================================
# UI REFS
# =====================================================

@onready var dimmer: ColorRect = %Dimmer
@onready var tutorial_panel: PanelContainer = %TutorialPanel
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var hint_label: Label = %HintLabel
@onready var continue_button: Button = %ContinueButton


# =====================================================
# READY
# =====================================================

func _on_base_ready() -> void:
	animate_transitions = true
	fade_duration_in = 0.25
	fade_duration_out = 0.20
	add_fade_target(tutorial_panel, 1.0)
	add_fade_target(dimmer, 0.35)

	visible = false
	continue_button.pressed.connect(advance_step)

	var save_mgr := ManagerLocator.get_save_manager()

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
		get_viewport().set_input_as_handled()


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
	hint_label.text = "[Click, Enter o Continuar]"

	_play_fade_in()
	continue_button.grab_focus()


# =====================================================
# ADVANCE
# =====================================================

func advance_step() -> void:
	if state != State.SHOWING:
		return

	state = State.TRANSITIONING

	await _play_fade_out()

	step_index += 1

	state = State.SHOWING

	show_step()


# =====================================================
# FINISH
# =====================================================

func finish_tutorial() -> void:
	if state == State.FINISHED:
		return

	state = State.FINISHED

	visible = false

	tutorial_finished.emit()

	var save_mgr := ManagerLocator.get_save_manager()

	if save_mgr:
		save_mgr.first_time_player = false
		save_mgr.save_game()

	queue_free()
