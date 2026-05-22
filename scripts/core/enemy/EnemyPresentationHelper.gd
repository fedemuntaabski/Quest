extends RefCounted
class_name EnemyPresentationHelper

static func update_health_bar_on_hp_changed(health_bar: ProgressBar, is_tutorial_enemy: bool, current_hp: int, max_hp: int) -> void:
	if health_bar == null:
		return
	if is_tutorial_enemy:
		return
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	health_bar.visible = true

static func set_targeted_state(
	health_bar: ProgressBar,
	sprite: Sprite2D,
	active: bool,
	target_tint: Color,
	base_modulate: Color
) -> void:
	if health_bar:
		health_bar.visible = active or health_bar.value < health_bar.max_value
	if sprite:
		sprite.modulate = target_tint if active else base_modulate

static func spawn_floating_text(host: Node, text: String, color: Color, crit: bool) -> void:
	if host == null:
		return
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100
	label.position = Vector2(-12, -28)
	if crit:
		label.scale = Vector2(1.2, 1.2)
	host.add_child(label)

	var tween := host.create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -18), 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

static func show_damage_feedback(host: Node2D, amount: int, crit: bool = false) -> void:
	if host == null:
		return
	spawn_floating_text(host, "-%d" % amount, Color(1, 0.2, 0.2), crit)

	var vfs := host.get_tree().get_nodes_in_group("visual_feedback")
	if vfs.size() > 0:
		var vf := vfs[0]
		vf.request_damage_flash(host, Color(1, 0.9, 0.9), 0.12)
		vf.request_particles(host.global_position, Color(1.0, 0.6, 0.2), 6)
		vf.request_hit_pause(0.04, 0.18)
		vf.request_screen_shake(2.0, 0.12)

static func show_miss_feedback(host: Node2D) -> void:
	spawn_floating_text(host, "MISS", Color(0.9, 0.9, 0.9), false)

static func refresh_status_indicator(host: Node) -> void:
	if host == null:
		return
	var indicator := host.get_node_or_null("StatusIndicator")
	if indicator and indicator.has_method("refresh_statuses"):
		var statuses: Dictionary = {}
		var status_comp := host.get_node_or_null("StatusComponent") as StatusComponent
		if status_comp != null:
			statuses = status_comp.statuses.duplicate(true)
		else:
			statuses = StatusRuntime._get_statuses(host)
		indicator.refresh_statuses(statuses)
