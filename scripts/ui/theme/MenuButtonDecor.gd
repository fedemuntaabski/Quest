class_name MenuButtonDecor
extends Control

## menu-33: hover/focus marker of a menu plaque (UiStyles.style_plaque_button): a gold
## lozenge at the left edge that lights into a small ember flame, and an underline that
## sweeps out under the text. Drawn in code (no art), an internal child of the button so
## loops over the button's children don't see it. Real time: tweens ignore time scale.

const NODE_NAME := "MenuButtonDecor"

var danger: bool = false
## 0 = idle, 1 = hovered/focused.
var heat: float = 0.0:
	set(value):
		heat = value
		set_process(heat > 0.01)
		queue_redraw()

var _button: Button
var _hovered: bool = false
var _focused: bool = false
var _tween: Tween


static func attach(button: Button, is_danger: bool = false) -> MenuButtonDecor:
	var existing := of(button)
	if existing:
		existing.danger = is_danger
		return existing
	var decor := MenuButtonDecor.new()
	decor.name = NODE_NAME
	decor.danger = is_danger
	button.add_child(decor, false, Node.INTERNAL_MODE_BACK)
	return decor


static func of(button: Node) -> MenuButtonDecor:
	if button == null:
		return null
	for child in button.get_children(true):
		if child is MenuButtonDecor:
			return child
	return null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_button = get_parent() as Button
	if _button == null:
		return
	_button.mouse_entered.connect(_set_hovered.bind(true))
	_button.mouse_exited.connect(_set_hovered.bind(false))
	_button.focus_entered.connect(_set_focused.bind(true))
	_button.focus_exited.connect(_set_focused.bind(false))
	_button.visibility_changed.connect(_on_button_visibility_changed)


func _set_hovered(on: bool) -> void:
	_hovered = on
	_update()


func _set_focused(on: bool) -> void:
	_focused = on
	_update()


func _on_button_visibility_changed() -> void:
	if not _button.is_visible_in_tree():
		_hovered = false
		_focused = _button.has_focus()
		heat = 1.0 if _focused else 0.0


func _update() -> void:
	var target := 1.0 if (_focused or (_hovered and not _button.disabled)) else 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		heat = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.set_ignore_time_scale(true)
	_tween.tween_property(self, "heat", target, 0.22 if target > heat else 0.3)


func _process(_delta: float) -> void:
	queue_redraw()  # flame flicker while lit


func _draw() -> void:
	var h := size.y
	var cx := 23.0
	var cy := h * 0.5
	var r := 6.0 + 1.5 * heat
	var lit: Color = QuestPalette.BANNER_RED_LIGHT if danger else QuestPalette.RELIC_GOLD
	var glow: Color = QuestPalette.BANNER_RED_LIGHT if danger else QuestPalette.EMBER
	var idle := Color(QuestPalette.AGED_GOLD, 0.75)
	if heat > 0.0:
		draw_circle(Vector2(cx, cy), r * 2.4, Color(glow, 0.14 * heat))
		draw_circle(Vector2(cx, cy), r * 1.5, Color(glow, 0.16 * heat))
	var lozenge := PackedVector2Array([
		Vector2(cx, cy - r), Vector2(cx + r * 0.72, cy), Vector2(cx, cy + r), Vector2(cx - r * 0.72, cy)])
	draw_colored_polygon(lozenge, idle.lerp(lit, heat))
	var outline := lozenge.duplicate()
	outline.append(lozenge[0])
	draw_polyline(outline, Color(QuestPalette.INK, 0.85), 1.0, true)
	if heat > 0.05:
		var t := Time.get_ticks_msec() / 1000.0
		var flick := 1.0 if Accessibility.reduce_flashes else 0.82 + 0.18 * sin(t * 15.0) * sin(t * 6.1 + 1.3)
		var fh := (8.0 + 4.0 * flick) * heat
		var base_y := cy - r + 2.0
		var sway := 0.0 if Accessibility.reduce_flashes else sin(t * 9.0) * 1.2
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 3.6, base_y), Vector2(cx + sway, base_y - fh), Vector2(cx + 3.6, base_y)]), Color(glow, 0.85 * heat))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 1.8, base_y), Vector2(cx + sway * 0.6, base_y - fh * 0.6), Vector2(cx + 1.8, base_y)]), Color(QuestPalette.RELIC_GOLD_PALE, heat))
		var x0 := 44.0
		var x1 := lerpf(x0, size.x - 20.0, ease(heat, 0.4))
		draw_line(Vector2(x0, h - 8.0), Vector2(x1, h - 8.0), Color(lit, 0.7 * heat), 1.5, true)
