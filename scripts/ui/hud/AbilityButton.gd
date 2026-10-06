class_name AbilityButton
extends Button

## AbilityButton (heroes-9): a hero's active ability on its HeroPortrait. Icon
## (AbilityData.icon), radial cooldown (dark pie that shrinks clockwise),
## "ready" state = pulsing gold border + the Q hint. Click = the same
## HeroAbilities.try_activate() as Q (it says why it refuses: pause, cooldown).
## Built in code by HeroPortrait; bind() after add_child.

const SIZE := Vector2(32, 32)
const SHADE := Color(0.0, 0.0, 0.0, 0.62)
const READY_PULSE_SEC := 0.9

var abilities: HeroAbilities
## 0 = ready, 1 = just used (fraction of the cooldown left).
var cooldown_fraction: float = 0.0
var _hint: Label
var _pulse: Tween
var _border_alpha: float = 1.0


func _ready() -> void:
	custom_minimum_size = SIZE
	expand_icon = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", UiStyles.build_panel_style(Color(0.08, 0.07, 0.07, 0.9), QuestPalette.GOLD_DARK, 1, 4, 2))
	_hint = Label.new()
	_hint.text = "Q"
	_hint.add_theme_font_size_override("font_size", 10)
	_hint.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.position = Vector2(SIZE.x - 9, SIZE.y - 14)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	pressed.connect(_on_pressed)
	visible = false


func bind(p_abilities: HeroAbilities) -> void:
	abilities = p_abilities
	visible = abilities != null and abilities.active != null
	if not visible:
		return
	icon = abilities.active.icon
	text = "" if icon else abilities.display_name().left(1)
	tooltip_text = "%s (Q)\n%s" % [abilities.display_name(), abilities.describe(abilities.active)]
	if not abilities.cooldown_changed.is_connected(_on_cooldown_changed):
		abilities.cooldown_changed.connect(_on_cooldown_changed)
	_on_cooldown_changed(abilities.cooldown_left, abilities.active_cooldown())


func is_ready() -> bool:
	return abilities != null and abilities.is_ready()


func _on_pressed() -> void:
	if abilities:
		abilities.try_activate()


func _on_cooldown_changed(left: float, total: float) -> void:
	cooldown_fraction = clampf(left / maxf(total, 0.001), 0.0, 1.0)
	_hint.visible = left <= 0.0
	_set_pulsing(left <= 0.0)
	if abilities:  # perks may have changed the numbers
		tooltip_text = "%s (Q)\n%s" % [abilities.display_name(), abilities.describe(abilities.active)]
	queue_redraw()


## Ready = the gold border breathes (real time: it also pulses in the tactical pause).
func _set_pulsing(on: bool) -> void:
	if on == (_pulse != null and _pulse.is_valid()):
		return
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_border_alpha = 1.0
	if on and is_inside_tree():
		_pulse = create_tween().set_loops().set_ignore_time_scale()
		_pulse.tween_method(_set_border_alpha, 1.0, 0.35, READY_PULSE_SEC * 0.5)
		_pulse.tween_method(_set_border_alpha, 0.35, 1.0, READY_PULSE_SEC * 0.5)
	queue_redraw()


func _set_border_alpha(a: float) -> void:
	_border_alpha = a
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if cooldown_fraction > 0.0:
		# Pie of what is left, starting at 12 o'clock, shrinking clockwise.
		var center := size * 0.5
		var radius := size.length() * 0.5
		var points := PackedVector2Array([center])
		var steps := 24
		var start := -PI * 0.5 + TAU * (1.0 - cooldown_fraction)
		for i in steps + 1:
			var angle := start + TAU * cooldown_fraction * float(i) / steps
			var p := center + Vector2(cos(angle), sin(angle)) * radius
			points.append(Vector2(clampf(p.x, 0.0, size.x), clampf(p.y, 0.0, size.y)))
		draw_colored_polygon(points, SHADE)
	else:
		draw_rect(rect.grow(-1.0), Color(QuestPalette.GOLD_LIGHT, _border_alpha), false, 2.0)
