extends RefCounted
class_name Main2dVictoryHandler

# Main2dVictoryHandler: presentation helper for victory overlay.
# Responsibilities:
# - Show victory UI and populate run summary labels; does not perform state changes.

var owner: Node = null
var victory_overlay: CanvasLayer = null
var victory_gold_label: Label = null

func setup(p_owner: Node, p_victory_overlay: CanvasLayer, p_victory_gold_label: Label) -> void:
	owner = p_owner
	victory_overlay = p_victory_overlay
	victory_gold_label = p_victory_gold_label

func show_victory_screen(run_gold: int) -> void:
	if owner == null:
		return

	if victory_gold_label:
		victory_gold_label.text = "Oro ganado: %d" % run_gold

	if victory_overlay:
		victory_overlay.visible = true

		var color_rect := victory_overlay.get_node_or_null("ColorRect") as ColorRect
		if color_rect:
			color_rect.modulate.a = 0.0

			var t := owner.create_tween()
			t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t.tween_property(color_rect, "modulate:a", 1.0, 2.0)
