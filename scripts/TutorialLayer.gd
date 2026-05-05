extends CanvasLayer

## TutorialLayer — Autónomo y desacoplado

var step: int = 0

var prompts = [
	"Usa el click izquierdo para moverte de forma por las casillas.", 
	"Tus stats base (HP, Strength, Magic, Dexterity) son fijas.",
	"El dado 1d6 bonifica tus ataques, pero no altera tus stats.",
	"Presiona TAB para ver tus estadísticas y mejoras.",
	"Gestiona tus 3 cartas para derrotar a los enemigos y avanzar.",
	"¡Derrota al enemigo final para completar el contrato!",
	"¡Buena suerte, cazarecompensas!"
]

var active_tween: Tween 
var is_transitioning: bool = false

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
	visible = true
	_show_next_prompt()

func _show_next_prompt() -> void:
	if step >= prompts.size():
		_finish_tutorial()
		return
	
	label.text = prompts[step]
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
	visible = false

	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.first_time_player = false
		save_mgr.save_game()

	queue_free()