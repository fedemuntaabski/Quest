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
	var host_2d := host as Node2D
	if host_2d == null:
		return
	var text_mgr := host.get_tree().get_first_node_in_group("floating_text_manager") as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text_from_host(host_2d, text, color, crit, Vector2(-12, -28), 18.0, 0.5)
		return

	# Fallback path keeps behavior if FloatingTextManager is unavailable.
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
	var palette := ThemeManager.get_combat_feedback_palette()
	spawn_floating_text(host, "-%d" % amount, palette["damage_text"], crit)
	CombatFeedbackPresenter.dispatch_hit_feedback(host)

static func show_miss_feedback(host: Node2D) -> void:
	var palette := ThemeManager.get_combat_feedback_palette()
	spawn_floating_text(host, "MISS", palette["miss_text"], false)

static func refresh_status_indicator(host: Node) -> void:
	if host == null:
		return
	var indicator := host.get_node_or_null("StatusIndicator")
	if indicator == null:
		return
	if not indicator.has_method("refresh_statuses"):
		return
	var statuses := StatusRuntime.get_statuses(host)
	indicator.refresh_statuses(statuses)
