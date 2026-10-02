class_name EndScreenOverlay
extends CanvasLayer

## Base of the run-end overlays (death/victory): shows itself with a fade-in of
## its `ColorRect`. Presentation only — the owner reacts to the signals the
## subclasses expose and decides what to do (reload, next floor, main menu).

const FADE_IN_SEC := 2.0


func show_screen() -> void:
	visible = true
	var color_rect := get_node_or_null("ColorRect") as ColorRect
	if color_rect == null:
		return
	color_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "modulate:a", 1.0, FADE_IN_SEC)
