extends Resource
class_name HealthBarStyle

## HealthBarStyle: colors, thresholds and timings of the HeroPortrait HP bar.
## Green above `high_threshold`, yellow between the thresholds (inclusive),
## red below `low_threshold`.

@export_range(0.0, 1.0, 0.01) var high_threshold: float = 0.6
@export_range(0.0, 1.0, 0.01) var low_threshold: float = 0.3

@export var high_color: Color = Color(0.35, 0.82, 0.4, 1.0)
@export var mid_color: Color = Color(0.95, 0.8, 0.3, 1.0)
@export var low_color: Color = Color(0.9, 0.25, 0.22, 1.0)
@export var background_color: Color = Color(0.1, 0.08, 0.08, 0.9)

@export_group("Feedback")
## Seconds the bar takes to slide/recolor to a new value.
@export var tween_time: float = 0.35
## Portrait modulate on damage, fading back to white over `flash_time`.
@export var flash_color: Color = Color(1.0, 0.45, 0.45, 1.0)
@export var flash_time: float = 0.2


func color_for(ratio: float) -> Color:
	if ratio > high_threshold:
		return high_color
	if ratio >= low_threshold:
		return mid_color
	return low_color


static func ratio_of(current_hp: int, max_hp: int) -> float:
	return clampf(float(current_hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
