extends CanvasLayer

## FPSOverlay — Autoload singleton
## Lightweight FPS counter overlay, toggled by SettingsManager.show_fps_overlay.

var label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	label = Label.new()
	label.add_theme_font_size_override("font_size", Accessibility.font(18))
	label.add_theme_color_override("font_color", Color(1, 1, 0.4, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	# visual-24: bottom-left, the one corner the HUD leaves free (top-right covered
	# the first hero portrait's name).
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_left = 8
	label.offset_top = -4
	label.offset_right = 160
	label.offset_bottom = -4
	add_child(label)

	visible = SettingsManager.show_fps_overlay
	SettingsManager.settings_changed.connect(_on_settings_changed)


func _process(_delta: float) -> void:
	if visible:
		label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_settings_changed(section: String, key: String, value: Variant) -> void:
	if section == SettingsManager.SECTION_DISPLAY and key == "show_fps_overlay":
		visible = bool(value)
