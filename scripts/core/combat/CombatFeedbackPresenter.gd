extends RefCounted
class_name CombatFeedbackPresenter

## Shared helper that dispatches combat visual feedback using centralized
## palette and timing presets. This keeps presentation callsites small
## while preserving existing values and sequencing.

static func dispatch_hit_feedback(host: Node2D) -> void:
	if host == null:
		return
	var vfs := host.get_tree().get_nodes_in_group("visual_feedback")
	if vfs.is_empty():
		return
	var vf := vfs[0]
	var palette := ThemeManager.get_combat_feedback_palette()
	var timing := ThemeManager.get_combat_feedback_timing()
	vf.request_damage_flash(host, palette["flash_tint"], float(timing["damage_flash_duration"]))
	vf.request_particles(host.global_position, palette["particle"], int(timing["particle_count"]))
	vf.request_hit_pause(float(timing["hit_pause_duration"]), float(timing["hit_pause_scale"]))
	vf.request_screen_shake(float(timing["screen_shake_intensity"]), float(timing["screen_shake_duration"]))
