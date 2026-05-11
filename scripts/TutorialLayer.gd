extends CanvasLayer

## TutorialLayer — Autonomo y desacoplado

signal tutorial_started
signal tutorial_finished

var step: int = 0

var prompts = [
	"Paso 1/5 - Movimiento: haz click en una casilla cercana para avanzar 1 turno.",
	"Paso 2/5 - Combate: acércate al enemigo verde del tutorial y atácalo con tus cartas.",
	"Paso 3/5 - Cartas: usa 1, 2, 3 para cambiar carta activa y revisa su alcance.",
	"Paso 4/5 - Información: mantén TAB para ver stats, cartas equipadas y progreso.",
	"Paso 5/5 - Tienda: usa tu oro para mejorar HP, Fuerza, Magia o Destreza."
]

var active_tween: Tween 
var is_transitioning: bool = false
var is_active: bool = false

var dungeon_generator: DungeonGenerator = null

@onready var label: Label = $Label
@onready var bg: ColorRect = $ColorRect

# ─────────────────────────────────────────────
# SETUP (NUEVO)
# ─────────────────────────────────────────────
func setup(dg: DungeonGenerator) -> void:
	dungeon_generator = dg

	if dungeon_generator and not dungeon_generator.room_cleared.is_connected(_on_room_cleared):
		dungeon_generator.room_cleared.connect(_on_room_cleared)

# ─────────────────────────────────────────────
# INIT
# ─────────────────────────────────────────────
func _ready() -> void:
	layer = 15
	visible = false

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.first_time_player:
		call_deferred("_start_tutorial")
	else:
		queue_free()

# ─────────────────────────────────────────────
# INPUT
# ─────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if visible and not is_transitioning:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
			_advance_tutorial()

# ─────────────────────────────────────────────
# FLOW
# ─────────────────────────────────────────────
func _start_tutorial() -> void:
	is_active = true
	visible = true
	tutorial_started.emit()
	_show_next_prompt()

func _show_next_prompt() -> void:
	if step >= prompts.size():
		_finish_tutorial()
		return
	
	label.text = "%s\n\n[Click izquierdo o Enter para continuar]" % prompts[step]
	is_transitioning = false
	
	if active_tween:
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(label, "modulate:a", 1.0, 0.5).from(0.0)
	active_tween.tween_property(bg, "modulate:a", 0.6, 0.5).from(0.0)

func _advance_tutorial() -> void:
	is_transitioning = true
	
	if active_tween:
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	active_tween.tween_property(bg, "modulate:a", 0.0, 0.3)
	
	await active_tween.finished
	
	step += 1
	_show_next_prompt()

# ─────────────────────────────────────────────
# EVENTOS DEL JUEGO
# ─────────────────────────────────────────────
func _on_room_cleared(_room_id: int) -> void:
	# 🔥 El tutorial decide qué hacer con este evento
	_finish_tutorial()

# ─────────────────────────────────────────────
# FINALIZACIÓN
# ─────────────────────────────────────────────
func _finish_tutorial() -> void:
	is_active = false
	visible = false
	tutorial_finished.emit()

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.first_time_player = false
		save_mgr.save_game()

	queue_free()