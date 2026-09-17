extends CanvasLayer

## FPSOverlay — Autoload singleton
## Lightweight FPS counter overlay, toggled by SettingsManager.show_fps_overlay.

var label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	label = Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 1, 0.4, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -120
	label.offset_top = 8
	label.offset_right = -8
	label.offset_bottom = 32
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(label)

	visible = SettingsManager.show_fps_overlay
	SettingsManager.settings_changed.connect(_on_settings_changed)


func _process(_delta: float) -> void:
	if visible:
		label.text = "FPS: %d" % Engine.get_frames_per_second()


func _on_settings_changed(section: String, key: String, value: Variant) -> void:
	if section == SettingsManager.SECTION_DISPLAY and key == "show_fps_overlay":
		visible = bool(value)
