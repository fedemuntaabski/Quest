class_name EndScreenOverlay
extends CanvasLayer

## Base of the run-end overlays (death/victory): shows itself with a fade-in of
## its `ColorRect`. Presentation only — the owner reacts to the signals the
## subclasses expose and decides what to do (reload, next floor, main menu).

const FADE_IN_SEC := 2.0
## coop-12: only the host continues the run (next floor, retry, new run).
const HOST_ONLY_BUTTONS := ["NextFloorButton", "NewRunButton", "RetryButton"]


func show_screen() -> void:
	visible = true
	if Net.is_online() and not Net.is_authority():
		for button in find_children("*", "Button", true, false):
			if HOST_ONLY_BUTTONS.has(String(button.name)):
				button.visible = false
				var wait := Label.new()
				wait.text = "Esperando al anfitrión…"
				button.get_parent().add_child(wait)
				button.get_parent().move_child(wait, button.get_index())
	var color_rect := get_node_or_null("ColorRect") as ColorRect
	if color_rect == null:
		return
	color_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "modulate:a", 1.0, FADE_IN_SEC)


## A RunSummary inside `box`, just before `before` (the buttons).
func add_summary(box: Node, before: Node) -> RunSummary:
	var run_summary := RunSummary.new()
	run_summary.name = "RunSummary"
	box.add_child(run_summary)
	box.move_child(run_summary, before.get_index())
	return run_summary
