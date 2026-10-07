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


@export_group("Colorblind (Accessibility.colorblind)")
## Okabe-Ito based: blue / yellow / vermillion differ in hue AND lightness, and
## each state also gets a glyph (glyph_for), so color is never the only cue.
@export var cb_high_color: Color = Color(0.34, 0.71, 0.91, 1.0)
@export var cb_mid_color: Color = Color(0.94, 0.89, 0.26, 1.0)
@export var cb_low_color: Color = Color(0.84, 0.37, 0.0, 1.0)


func color_for(ratio: float) -> Color:
	var cb := Accessibility.colorblind
	if ratio > high_threshold:
		return cb_high_color if cb else high_color
	if ratio >= low_threshold:
		return cb_mid_color if cb else mid_color
	return cb_low_color if cb else low_color


## Shape cue next to the bar: none when healthy, "▲" hurt, "!" critical.
## Always shown in colorblind mode; the critical "!" also with reduce_flashes
## (it replaces the low-HP blink).
func glyph_for(ratio: float) -> String:
	if ratio > high_threshold:
		return ""
	if ratio >= low_threshold:
		return "▲" if Accessibility.colorblind else ""
	return "!" if Accessibility.colorblind or Accessibility.reduce_flashes else ""


static func ratio_of(current_hp: int, max_hp: int) -> float:
	return clampf(float(current_hp) / float(max_hp), 0.0, 1.0) if max_hp > 0 else 0.0
