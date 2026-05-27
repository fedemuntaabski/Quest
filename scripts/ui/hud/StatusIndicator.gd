extends Node2D
class_name StatusIndicatorUI

@onready var icons_container: HBoxContainer = $IconContainer

func _ready() -> void:
	# Keep it lightweight; visibility controlled by owner
	visible = true
	set_process(false)

func refresh_statuses(statuses: Dictionary) -> void:
	# Clear existing
	for child in icons_container.get_children():
		child.queue_free()

	if statuses == null or statuses.is_empty():
		visible = false
		return

	visible = true
	# For each status, create a small icon + label
	for key in statuses.keys():
		var info: Dictionary = statuses[key] as Dictionary
		var duration: int = int(info.get("duration", 0))
		var icon_path: String = _status_icon_path(key)
		var tex: Texture2D = null
		if icon_path != "":
			tex = load(icon_path) as Texture2D

		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24,24)
		if str(key).to_lower() == "stun":
			icon.custom_minimum_size = Vector2(28, 28)
			icon.modulate = Color(0.92, 0.92, 0.95, 1.0)
		if tex:
			icon.texture = tex
		icons_container.add_child(icon)

		var lbl := Label.new()
		lbl.text = str(duration)
		lbl.add_theme_font_size_override("font_size", 12)
		icons_container.add_child(lbl)

func _status_icon_path(status_id: String) -> String:
	match status_id.to_lower():
		"poison":
			return "res://assets/ui/status/status_poison.svg"
		"burn":
			return "res://assets/ui/status/status_burn.svg"
		"stun":
			return "res://assets/ui/status/status_stun.svg"
		"freeze":
			return "res://assets/ui/status/status_freeze.svg"
		"arcane_shield":
			return "res://assets/ui/status/status_arcane_shield.svg"
		_:
			return ""
