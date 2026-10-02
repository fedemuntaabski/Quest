extends RefCounted
class_name Main2dVictoryHandler

# Main2dVictoryHandler: presentation helper for victory overlay.
# Responsibilities:
# - Show victory UI; does not perform state changes.

var owner: Node = null
var victory_overlay: CanvasLayer = null

func setup(p_owner: Node, p_victory_overlay: CanvasLayer) -> void:
	owner = p_owner
	victory_overlay = p_victory_overlay

func show_victory_screen() -> void:
	if owner == null:
		return

	if victory_overlay:
		victory_overlay.visible = true

		var color_rect := victory_overlay.get_node_or_null("ColorRect") as ColorRect
		if color_rect:
			color_rect.modulate.a = 0.0

			var t := owner.create_tween()
			t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t.tween_property(color_rect, "modulate:a", 1.0, 2.0)
