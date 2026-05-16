extends PointLight2D
class_name TorchLight

@export var base_energy: float = 1.8
@export var slow_flicker_speed: float = 1.0
@export var fast_flicker_speed: float = 14.0
@export var flicker_intensity: float = 0.25
@export_range(0.0, 1.0) var stability: float = 0.6
@export var response_speed: float = 6.0
@export var follow_speed: float = 8.0

var t: float = 0.0
var noise := FastNoiseLite.new()
var target_position: Vector2

func _ready():
	# Softer, wider torch range
	texture_scale = 2.6

	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.6

	base_energy *= randf_range(0.9, 1.1)

func _process(delta: float) -> void:
	t += delta

	var slow = sin(t * slow_flicker_speed) * 0.4
	var fast = sin(t * fast_flicker_speed + noise.get_noise_1d(t) * 2.0)
	var organic = noise.get_noise_1d(t * 0.8)

	var choke = 0.0
	if randf() > 0.985 * (1.0 - stability):
		choke = -randf_range(0.2, 0.6)

	var flicker = (slow * 0.5 + fast * 0.3 + organic * 0.4) * flicker_intensity

	var target_energy = base_energy + flicker + choke

	target_energy = clamp(target_energy, base_energy * 0.4, base_energy * 1.3)

	energy = lerp(energy, target_energy, delta * response_speed)

	# Position smoothing for organic light follow
	var parent_node = get_parent()
	if parent_node:
		target_position = parent_node.global_position
		global_position = global_position.lerp(target_position, delta * follow_speed)