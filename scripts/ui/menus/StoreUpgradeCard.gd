extends PanelContainer
class_name StoreUpgradeCard

signal upgrade_pressed(stat_key: String)
signal hovered(hint: String)
signal unhovered

@export var hover_scale: Vector2 = Vector2(1.04, 1.04)
@export var hover_tween_duration: float = 0.12
@export var border_width: int = 3
@export var border_width_hover: int = 4

@onready var stat_label: Label = %StatLabel
@onready var effect_label: Label = %EffectLabel
@onready var level_label: Label = %LevelLabel
@onready var cost_label: Label = %CostLabel
@onready var upgrade_button: Button = %UpgradeButton

var _stat_key: String = ""
var _accent_color: Color = QuestPalette.GOLD
var _hover_tween: Tween = null


func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	upgrade_button.pressed.connect(func() -> void: upgrade_pressed.emit(_stat_key))
	_apply_style(false)


func configure(stat_key: String, accent: Color) -> void:
	_stat_key = stat_key
	_accent_color = accent
	stat_label.add_theme_color_override("font_color", accent)


func set_data(title: String, effect: String, level: int, max_level: int, cost: int, can_upgrade: bool, affordable: bool) -> void:
	stat_label.text = title
	effect_label.text = effect
	level_label.text = "Nivel %d/%d" % [level, max_level]
	cost_label.text = "MAX" if not can_upgrade else "%dg" % cost
	upgrade_button.disabled = not (can_upgrade and affordable)
	upgrade_button.text = "MAX NIVEL" if not can_upgrade else "MEJORAR"

	var hint: String = "%s\nNivel %d/%d\nCosto: %dg\n%s" % [title, level, max_level, cost, effect]
	set_meta("upgrade_hint", hint)


func _on_mouse_entered() -> void:
	_apply_style(true)
	_tween_scale(hover_scale)
	hovered.emit(str(get_meta("upgrade_hint", "")))


func _on_mouse_exited() -> void:
	_apply_style(false)
	_tween_scale(Vector2.ONE)
	unhovered.emit()


func _apply_style(is_hovered: bool) -> void:
	var border: Color = _accent_color if is_hovered else QuestPalette.UI_PANEL_BORDER
	var width: int = border_width_hover if is_hovered else border_width
	add_theme_stylebox_override("panel", ThemeManager.build_panel_style(QuestPalette.DUNGEON_MUD, border, width, 16, 18))


func _tween_scale(target: Vector2) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target, hover_tween_duration)
