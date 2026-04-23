extends PointLight2D

class_name TorchLight

# Flickering settings
@export var flicker_speed: float = 0.1
@export var flicker_intensity: float = 0.3
@export var base_energy: float = 1.5

var time_elapsed: float = 0.0
var original_energy: float

func _ready():
	original_energy = energy
	energy = base_energy
	color = Color(1.0, 0.7, 0.4)  # Warm orange torch color
	texture_scale = 1.5

func _process(delta: float):
	time_elapsed += delta
	
	# Create flickering effect using sine wave with random perturbations
	var flicker = sin(time_elapsed * flicker_speed * PI) * flicker_intensity
	var random_flicker = randf_range(-flicker_intensity * 0.5, flicker_intensity * 0.5)
	
	energy = base_energy + flicker + random_flicker
	energy = clamp(energy, base_energy * 0.6, base_energy * 1.4)
