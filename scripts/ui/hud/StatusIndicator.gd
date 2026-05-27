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
	var owner_node := get_parent()
	var owner_is_enemy := owner_node != null and owner_node.is_in_group("enemy")
	# For each status, create a small icon + label
	for key in statuses.keys():
		var info: Dictionary = statuses[key] as Dictionary
		var duration: int = int(info.get("duration", 0))
		var stacks: int = int(info.get("stacks", 1))
		var status_id := str(key).to_lower()
		if status_id == "arcane_mark":
			var mark_chip := ColorRect.new()
			mark_chip.custom_minimum_size = Vector2(24, 24)
			mark_chip.color = Color(0.45, 0.74, 1.0, 0.95)
			icons_container.add_child(mark_chip)

			var mark_lbl := Label.new()
			mark_lbl.text = str(duration)
			mark_lbl.add_theme_font_size_override("font_size", 12)
			icons_container.add_child(mark_lbl)
			continue
		if owner_is_enemy and status_id == "stun":
			var stun_lbl := Label.new()
			stun_lbl.text = str(duration)
			stun_lbl.add_theme_font_size_override("font_size", 12)
			icons_container.add_child(stun_lbl)
			continue
		if status_id == "reflexes":
			var dodge_chip := ColorRect.new()
			dodge_chip.custom_minimum_size = Vector2(24, 24)
			dodge_chip.color = Color(0.50, 0.66, 0.95, 0.95)
			icons_container.add_child(dodge_chip)

			var dodge_lbl := Label.new()
			dodge_lbl.text = "%d|%d" % [stacks, duration]
			dodge_lbl.add_theme_font_size_override("font_size", 12)
			icons_container.add_child(dodge_lbl)
			continue
		if status_id == "exposed":
			var exposed_chip := ColorRect.new()
			exposed_chip.custom_minimum_size = Vector2(24, 24)
			exposed_chip.color = Color(0.97, 0.72, 0.25, 0.95)
			icons_container.add_child(exposed_chip)

			var exposed_lbl := Label.new()
			exposed_lbl.text = str(duration)
			exposed_lbl.add_theme_font_size_override("font_size", 12)
			icons_container.add_child(exposed_lbl)
			continue
		if status_id == "brutal_cut":
			var contrast_chip := ColorRect.new()
			contrast_chip.custom_minimum_size = Vector2(24, 24)
			contrast_chip.color = Color(0.88, 0.25, 0.42, 0.95)
			icons_container.add_child(contrast_chip)
			continue
		var icon_path: String = _status_icon_path(key)
		var tex: Texture2D = null
		if icon_path != "":
			tex = load(icon_path) as Texture2D

		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24,24)
		if status_id == "stun":
			icon.custom_minimum_size = Vector2(28, 28)
			icon.modulate = Color(0.92, 0.92, 0.95, 1.0)
		if tex:
			icon.texture = tex
		icons_container.add_child(icon)

		var lbl := Label.new()
		lbl.text = str(duration)
		lbl.add_theme_font_size_override("font_size", 12)
		if status_id == "brutal_cut":
			lbl.visible = false
		icons_container.add_child(lbl)

func _status_icon_path(status_id: String) -> String:
	match status_id.to_lower():
		"poison":
			return "res://assets/ui/status/status_poison.svg"
		"burn":
			return "res://assets/ui/status/status_burn.svg"
		"stun":
			return "res://assets/ui/status/status_stun.svg"
		"brutal_cut":
			return ""
		"arcane_mark":
			return ""
		"freeze":
			return "res://assets/ui/status/status_freeze.svg"
		"reflexes":
			return ""
		"exposed":
			return ""
		"arcane_shield":
			return "res://assets/ui/status/status_arcane_shield.svg"
		_:
			return ""
