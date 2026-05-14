extends Control
class_name UpgradePanelUI

@onready var vbox: VBoxContainer = $ScrollContainer/VBoxContainer

var _tooltip_host: HUDController = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tooltip_host = get_tree().get_first_node_in_group("hud") as HUDController

func refresh(upgrades: Array) -> void:
	for child in vbox.get_children():
		child.queue_free()

	if upgrades.is_empty():
		var empty_panel := PanelContainer.new()
		empty_panel.custom_minimum_size = Vector2(0, 64)
		empty_panel.add_theme_stylebox_override("panel", _build_row_style())
		var empty_label := Label.new()
		empty_label.text = "No upgrades active."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_panel.add_child(empty_label)
		vbox.add_child(empty_panel)
		return

	for upg in upgrades:
		vbox.add_child(_create_upgrade_card(upg))

func _create_upgrade_card(upg: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _build_row_style())
	card.mouse_entered.connect(_on_upgrade_hovered.bind(upg))
	card.mouse_exited.connect(_on_upgrade_hover_exited)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)

	var title := Label.new()
	title.text = str(upg.get("card_name", "???"))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.55, 1))
	row.add_child(title)

	var line := Label.new()
	line.text = "%s: +%d" % [str(upg.get("stat_affected", "")), int(upg.get("value_change", 0))]
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0, 1))
	row.add_child(line)

	var summary := Label.new()
	summary.text = _build_upgrade_summary(upg)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color(0.7, 0.7, 0.76, 1))
	row.add_child(summary)

	return card

func _on_upgrade_hovered(upg: Dictionary) -> void:
	if _tooltip_host == null:
		return
	_tooltip_host.show_card_tooltip(_build_tooltip_payload(upg))

func _on_upgrade_hover_exited() -> void:
	if _tooltip_host:
		_tooltip_host.hide_card_tooltip()

func _build_tooltip_payload(upg: Dictionary) -> Dictionary:
	return {
		"name": str(upg.get("card_name", "Upgrade")),
		"description": _build_upgrade_summary(upg),
		"range": 0,
		"cooldown": 0,
		"cooldown_remaining": 0,
		"scaling_stat": str(upg.get("stat_affected", "")),
		"stat": str(upg.get("stat_affected", "")),
		"damage_scaling": 1.0,
		"is_usable": true,
		"state": "upgrade"
	}

func _build_upgrade_summary(upg: Dictionary) -> String:
	var card_name := str(upg.get("card_name", "Upgrade"))
	var stat_key := str(upg.get("stat_affected", ""))
	var value_change := int(upg.get("value_change", 0))
	return "%s improves %s by %d." % [card_name, stat_key, value_change]

func _build_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.28, 0.3, 0.35, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style