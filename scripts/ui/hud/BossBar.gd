class_name BossBar
extends VBoxContainer

## BossBar (progresion-10): top-center name + HP bar of the floor's boss while it
## lives (EnemyManager.boss_spawned). Code-built by HUDController; IGNORE mouse.

const BAR_SIZE := Vector2(420, 14)
const TOP := 16

var boss: Enemy
var _name: Label
var _bar: ProgressBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 18)
	_name.add_theme_color_override("font_color", QuestPalette.BLOOD_LIGHT)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.show_percentage = false
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_stylebox_override("background", UiStyles.build_panel_style(Color(0.08, 0.05, 0.05, 0.9), QuestPalette.UI_PANEL_BORDER, 2, 3, 0))
	_bar.add_theme_stylebox_override("fill", UiStyles.build_panel_style(QuestPalette.BLOOD_LIGHT, QuestPalette.BLOOD_LIGHT, 0, 3, 0))
	add_child(_bar)


func track(p_boss: Enemy) -> void:
	boss = p_boss
	_name.text = "%s — %s" % [BestiaryPanel.boss_label(boss.type), boss.type.display_name]
	_bar.max_value = boss.max_hp
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, TOP)


func _process(_delta: float) -> void:
	if boss == null:
		return
	if not is_instance_valid(boss) or not boss.is_alive():
		boss = null
		visible = false
		return
	_bar.value = boss.current_hp
