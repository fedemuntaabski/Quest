extends CanvasLayer

## TutorialLayer — Contextual onboarding for new players.

var step: int = 0
var prompts = [
	"Use W, A, S, D to move and click to attack.",
	"Press TAB to view your stats and upgrades.",
	"Stay in the light. Avoid the darkness."
]

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

func _start_tutorial() -> void:
	visible = true
	_show_next_prompt()

func _show_next_prompt() -> void:
	if step >= prompts.size():
		return
	
	label.text = prompts[step]
	label.modulate.a = 0.0
	bg.modulate.a = 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 1.0)
	tween.tween_property(bg, "modulate:a", 0.6, 1.0)
	
	await get_tree().create_timer(4.5).timeout
	
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(label, "modulate:a", 0.0, 1.0)
	fade_tween.tween_property(bg, "modulate:a", 0.0, 1.0)
	
	await fade_tween.finished
	
	step += 1
	if step < prompts.size():
		_show_next_prompt()

func _on_room_cleared(room_id: int) -> void:
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.first_time_player:
		save_mgr.first_time_player = false
		save_mgr.save_game()
		queue_free()
