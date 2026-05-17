extends Node2D
class_name VisualFeedback

signal screen_shake(intensity: float, duration: float)

@export var particle_count: int = 6
@export var particle_lifetime: float = 0.45
@export var damage_flash_duration: float = 0.12
@export var hit_pause_duration: float = 0.04
@export var hit_pause_scale: float = 0.18

var _hit_pause_stack: int = 0
var _prev_time_scale: float = 1.0

func _ready() -> void:
	add_to_group("visual_feedback")

func request_damage_flash(target: Node, color: Color, duration: float = -1.0) -> void:
	if duration <= 0.0:
		duration = damage_flash_duration

	var sprite := _find_sprite(target)
	if sprite == null:
		return

	var original := sprite.modulate
	sprite.modulate = color

	var tw := create_tween()
	tw.tween_property(sprite, "modulate", original, duration)

func request_particles(pos: Vector2, color: Color, count: int = -1) -> void:
	if count <= 0:
		count = particle_count

	for i in range(count):
		var rect := ColorRect.new()
		rect.color = color
		rect.size = Vector2.ONE * randi_range(4, 10)
		var node := Node2D.new()
		node.add_child(rect)
		add_child(node)
		node.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))

		var tw := create_tween()
		tw.tween_property(node, "scale", Vector2.ZERO, particle_lifetime)
		tw.parallel().tween_property(rect, "modulate:a", 0.0, particle_lifetime)
		tw.tween_callback(Callable(node, "queue_free"))

func request_hit_pause(duration: float = -1.0, timescale: float = -1.0) -> void:
	if duration <= 0.0:
		duration = hit_pause_duration
	if timescale <= 0.0:
		timescale = hit_pause_scale

	# Stack time scale requests
	if _hit_pause_stack == 0:
		_prev_time_scale = Engine.time_scale
		Engine.time_scale = timescale
	_hit_pause_stack += 1

	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(Callable(self, "_on_hit_pause_restore"))

func request_screen_shake(intensity: float = 2.0, duration: float = 0.12) -> void:
	emit_signal("screen_shake", intensity, duration)

func _find_sprite(target: Node) -> CanvasItem:
	if target == null:
		return null
	if target is CanvasItem:
		# prefer direct Sprite2D child named Sprite2D
		var s := target.get_node_or_null("Sprite2D")
		if s and s is CanvasItem:
			return s
		# fallback: first CanvasItem child
		for child in target.get_children():
			if child is CanvasItem:
				return child
		return target as CanvasItem
	return null

func _noop() -> void:
	pass

func _on_hit_pause_restore() -> void:
	_hit_pause_stack -= 1
	if _hit_pause_stack <= 0:
		Engine.time_scale = _prev_time_scale
		_hit_pause_stack = 0
