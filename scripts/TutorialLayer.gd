extends CanvasLayer

## TutorialLayer — Contextual onboarding for new players.

var step: int = 0
var prompts = [
    "Usa WASD para moverte de forma ortogonal.", 
    "Tus stats base (HP, Strength, Magic, Dexterity) son fijas.",
    "El dado 1d6 bonifica tus ataques, pero no altera tus stats.",
    "Presiona TAB para ver tus estadísticas y mejoras.",
    "Gestiona tus 3 cartas para derrotar a los enemigos y avanzar.",
    "¡Derrota al enemigo final para completar el contrato!",
    "¡Buena suerte, cazarecompensas!"
]

var active_tween: Tween 
var is_transitioning: bool = false


@onready var label: Label = $Label
@onready var bg: ColorRect = $ColorRect

func _ready() -> void:
	layer = 15
	visible = false
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.first_time_player:
		call_deferred("_start_tutorial")
	else:
		queue_free()

# Detecta clics o espacio para avanzar
func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed):
		_advance_tutorial()

func _start_tutorial() -> void:
	visible = true
	_show_next_prompt()

func _show_next_prompt() -> void:
	if step >= prompts.size():
		_finish_tutorial()
		return
	
	label.text = prompts[step]
	is_transitioning = false # Permitir input de nuevo
	
	# Control de Tweens: Matamos el anterior si existe para evitar superposiciones
	if active_tween:
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(label, "modulate:a", 1.0, 0.5).from(0.0)
	active_tween.tween_property(bg, "modulate:a", 0.6, 0.5).from(0.0)

func _advance_tutorial() -> void:
	is_transitioning = true # Bloquear input durante la transición
	# Animación de salida rápida antes de pasar al siguiente
	if active_tween:
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(label, "modulate:a", 0.0, 0.3)
	active_tween.tween_property(bg, "modulate:a", 0.0, 0.3)
	
	await active_tween.finished
	step += 1
	_show_next_prompt()

func _finish_tutorial() -> void:
	visible = false
	# Aquí podrías emitir una señal o marcar el tutorial como completado
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.first_time_player = false
		save_mgr.save_game()
	queue_free()

func _on_room_cleared(_room_id: int) -> void:
	_finish_tutorial()
