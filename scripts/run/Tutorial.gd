extends Node
class_name Tutorial

## Tutorial (intro-tutorial-17): the menu's guided first floor. Built by Main2d only
## when GameSession.tutorial; the HUD reads it (ObjectivePanel lines, HelpCard).
## Each step ends on a real game event, never on time. An event that comes early
## (a room lit before the move step) is kept, so the steps never block each other.

signal step_changed(step: int)

## Heroes of the Tutorial party (fixed): the warrior starts selected.
const HEROES: Array[String] = ["warrior", "mage"]
enum Step { SELECT, OPEN_DOOR, MOVE, LIGHT, BUILD, FIND_EXIT, TAKE_RELIC, CARRY, DONE }
## Step -> [objective line, help title, help body]. %s in BUILD = the build_major key.
const STEPS := [
	["Elegí al Mago", "Elegir héroes", "Clic izquierdo sobre el Mago o sobre su retrato (arriba a la derecha) para elegirlo. También sirve F2; Ctrl+clic suma héroes a la selección."],
	["Abrí la puerta de la sala", "Abrir puertas", "Clic izquierdo en la puerta: los héroes elegidos la abren y entran. Cada puerta da Brasas y otro recurso, pero puede despertar enemigos."],
	["Volvé a la sala inicial con clic derecho", "Moverse", "Clic derecho sobre una sala descubierta: los héroes elegidos caminan hasta ella. Probá volver a la sala inicial."],
	["Encendé la sala nueva con clic central", "Encender salas", "De las salas oscuras salen enemigos. Clic central sobre la sala nueva para encenderla con Brasas; el costo está escrito en la sala."],
	["Construí una obra en la sala encendida", "Construir obras", "Una sala encendida tiene huecos. Abrí las obras mayores con %s, elegí una carta y hacé clic en un hueco marcado. La Forja da Hierro por puerta abierta."],
	["Abrí puertas hasta encontrar la salida", "Buscar la salida", "La salida es la sala más lejana. Seguí abriendo puertas: cuando aparece, una flecha en el borde de la pantalla la señala."],
	["Recogé la Reliquia en la sala inicial", "La Reliquia", "Con la salida descubierta, llevá un héroe a la sala inicial y hacé clic izquierdo en la Reliquia. Desde ese momento no se abren puertas y llegan oleadas."],
	["Llevá la Reliquia a la salida", "Escapar", "El portador camina más lento. Llevalo con clic derecho hasta la salida mientras los demás lo cubren."],
	["Tutorial completado", "Tutorial completado", "Ya sabés lo básico. Una partida normal tiene cinco pisos, cada uno más hondo y con más enemigos."],
]

var step: int = Step.SELECT
var _hit: Dictionary = {}
var _main2d: Node


func _ready() -> void:
	add_to_group("tutorial")


func setup(main2d: Node) -> void:
	_main2d = main2d
	var selection := ManagerLocator.get_selection_manager()
	if selection:
		selection.selection_changed.connect(func(_ids: Array[String]) -> void: hit(Step.SELECT))
	var doors: DoorTurnSystem = main2d.door_turn_system
	doors.turn_advanced.connect(func(_turn: int) -> void: hit(Step.OPEN_DOOR))
	doors.room_revealed.connect(func(_group: String, _cells: Array[Vector2i]) -> void: _check_exit())
	var rooms: RoomManager = main2d.room_manager
	rooms.zone_clicked.connect(_on_zone_clicked)
	rooms.room_light_changed.connect(func(zone_id: String, lit: bool) -> void:
		if lit and zone_id != rooms.get_start_zone_id():
			hit(Step.LIGHT))
	rooms.building_built.connect(func(_zone: String, _building: Building) -> void: hit(Step.BUILD))
	var extraction: ExtractionManager = main2d.extraction_manager
	extraction.phase_changed.connect(func(new_phase: ExtractionManager.Phase, _old: ExtractionManager.Phase) -> void:
		if new_phase == ExtractionManager.Phase.EXTRACTION:
			hit(Step.TAKE_RELIC))
	extraction.victory_declared.connect(func() -> void: hit(Step.CARRY))


func objective_text(i: int) -> String:
	return STEPS[i][0]


func help_title() -> String:
	return STEPS[step][1]


func help_body() -> String:
	var body: String = STEPS[step][2]
	return body % InputBindings.label("build_major") if "%s" in body else body


func is_done() -> bool:
	return step == Step.DONE


## A step's event happened (now or ahead of time). Advances over every step already hit.
func hit(which: int) -> void:
	_hit[which] = true
	var moved := false
	while step < Step.DONE and _hit.has(step):
		step += 1
		moved = true
	if moved:
		QuestLogger.info(QuestLogger.Category.UI, "Tutorial: step %d (%s)." % [step, objective_text(step)])
		step_changed.emit(step)


## A right click on a revealed zone where a selected hero is not: a real move order.
func _on_zone_clicked(zone_id: String) -> void:
	var rooms: RoomManager = _main2d.room_manager
	if not rooms.is_zone_revealed(zone_id):
		return
	var selection := ManagerLocator.get_selection_manager()
	for hero: Player in _main2d.heroes:
		if selection and selection.is_selected(hero.stats.hero_id) and hero.current_zone_id != zone_id:
			hit(Step.MOVE)
			return


func _check_exit() -> void:
	var rooms: RoomManager = _main2d.room_manager
	if rooms.is_zone_revealed(rooms.get_exit_zone_id()):
		hit(Step.FIND_EXIT)
