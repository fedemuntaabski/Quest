extends Node2D
class_name StatusIndicatorUI

const STATUS_ICONS := {
	"poison": preload("res://assets/ui/status/status_poison.svg"),
	"burn": preload("res://assets/ui/status/status_burn.svg"),
	"stun": preload("res://assets/ui/status/status_stun.svg"),
	"freeze": preload("res://assets/ui/status/status_freeze.svg"),
	"arcane_shield": preload("res://assets/ui/status/status_arcane_shield.svg")
}

@onready var icons_container: HBoxContainer = $IconContainer


func _ready() -> void:
	visible = true
	set_process(false)


func refresh_statuses(statuses: Dictionary) -> void:

	_clear_icons()

	if statuses.is_empty():
		visible = false
		return

	visible = true

	var owner_is_enemy := (
		get_parent() != null
		and get_parent().is_in_group("enemy")
	)

	for key in statuses.keys():

		var info: Dictionary = statuses[key]

		var status_id := str(key).to_lower()

		var duration := int(
			info.get("duration", 0)
		)

		var stacks := int(
			info.get("stacks", 1)
		)

		_add_status_visual(
			status_id,
			duration,
			stacks,
			owner_is_enemy
		)


func _clear_icons() -> void:

	for child in icons_container.get_children():
		child.queue_free()


func _add_status_visual(
	status_id: String,
	duration: int,
	stacks: int,
	owner_is_enemy: bool
) -> void:

	match status_id:

		"arcane_mark":
			_add_chip(
				Color(0.45, 0.74, 1.0, 0.95),
				str(duration)
			)

		"reflexes":
			_add_chip(
				Color(0.50, 0.66, 0.95, 0.95),
				"%d|%d" % [stacks, duration]
			)

		"exposed":
			_add_chip(
				Color(0.97, 0.72, 0.25, 0.95),
				str(duration)
			)

		"brutal_cut":
			_add_color_only_chip(
				Color(0.88, 0.25, 0.42, 0.95)
			)

		"stun":

			if owner_is_enemy:
				_add_label(str(duration))
				return

			_add_icon_status(
				status_id,
				str(duration),
				Vector2(28, 28)
			)

		_:
			_add_icon_status(
				status_id,
				str(duration)
			)


func _add_icon_status(
	status_id: String,
	text: String,
	size := Vector2(24, 24)
) -> void:

	var icon := TextureRect.new()

	icon.texture = STATUS_ICONS.get(status_id)

	icon.custom_minimum_size = size

	icon.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	if status_id == "stun":
		icon.modulate = Color(
			0.92,
			0.92,
			0.95,
			1.0
		)

	icons_container.add_child(icon)

	_add_label(text)


func _add_chip(
	color: Color,
	text: String
) -> void:

	var chip := ColorRect.new()

	chip.custom_minimum_size = Vector2(24, 24)
	chip.color = color

	icons_container.add_child(chip)

	_add_label(text)


func _add_color_only_chip(
	color: Color
) -> void:

	var chip := ColorRect.new()

	chip.custom_minimum_size = Vector2(24, 24)
	chip.color = color

	icons_container.add_child(chip)


func _add_label(
	text: String
) -> void:

	var label := Label.new()

	label.text = text

	label.add_theme_font_size_override(
		"font_size",
		12
	)

	icons_container.add_child(label)