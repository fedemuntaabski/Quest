extends RefCounted
class_name Main2dDeathHandler

# Main2dDeathHandler: presentation helper for death overlay.
# Responsibilities:
# - Show death UI and populate run summary labels; does not perform state changes.

var owner: Node = null
var death_overlay: CanvasLayer = null
var death_gold_label: Label = null

func setup(p_owner: Node, p_death_overlay: CanvasLayer, p_death_gold_label: Label) -> void:
	owner = p_owner
	death_overlay = p_death_overlay
	death_gold_label = p_death_gold_label

func show_death_screen(_enemies_killed: int, _rooms_cleared: int, run_gold: int) -> void:
	if owner == null:
		return

	# Display run-earned gold but do NOT add extra gold here (gold is awarded during gameplay)
	if death_gold_label:
		death_gold_label.text = "Oro ganado: %d" % run_gold

	if death_overlay:
		death_overlay.visible = true
		
		# Fade in the ColorRect (CanvasLayer doesn't have modulate, but ColorRect does)
		var color_rect := death_overlay.get_node_or_null("ColorRect") as ColorRect
		if color_rect:
			color_rect.modulate.a = 0.0
			
			var t := owner.create_tween()
			t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t.tween_property(color_rect, "modulate:a", 1.0, 2.0)

### Removed legacy wrapper `handle_player_died()` — no callers detected.
