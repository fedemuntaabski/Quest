extends Button
class_name BestiaryListItem

## BestiaryListItem: one square of the bestiary grid — the enemy's first idle
## frame, a black silhouette while UNKNOWN, gold border while selected.

signal chosen(type: EnemyType)

const SIZE := Vector2(72, 72)

var type: EnemyType
var tier: BestiaryEntry.Tier = BestiaryEntry.Tier.UNKNOWN
var _selected: bool = false


func setup(p_type: EnemyType, p_tier: BestiaryEntry.Tier) -> void:
	type = p_type
	custom_minimum_size = SIZE
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_NONE
	pressed.connect(func() -> void: chosen.emit(type))
	set_tier(p_tier)


func set_tier(p_tier: BestiaryEntry.Tier) -> void:
	tier = p_tier
	icon = first_frame(type)
	var known := tier != BestiaryEntry.Tier.UNKNOWN
	var tint := Color.WHITE if known else Color.BLACK
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		add_theme_color_override(state, tint)
	tooltip_text = type.display_name if known else "???"
	_apply_style()


func set_selected(on: bool) -> void:
	_selected = on
	_apply_style()


func _apply_style() -> void:
	var border := QuestPalette.GOLD if _selected else QuestPalette.UI_PANEL_BORDER
	var bg := QuestPalette.DUNGEON_MUD if tier != BestiaryEntry.Tier.UNKNOWN else QuestPalette.DUNGEON_STONE
	add_theme_stylebox_override("normal", UiStyles.build_panel_style(bg, border, 3 if _selected else 2, 6, 6))
	add_theme_stylebox_override("hover", UiStyles.build_panel_style(bg, QuestPalette.GOLD_LIGHT, 2, 6, 6))
	add_theme_stylebox_override("pressed", UiStyles.build_panel_style(bg, QuestPalette.GOLD, 3, 6, 6))


## Idle frame 0 of the type's SpriteFrames (null when it has no art).
static func first_frame(p_type: EnemyType) -> Texture2D:
	var frames := p_type.sprite_frames
	if frames == null:
		return null
	var names := frames.get_animation_names()
	var anim: StringName = &"idle" if frames.has_animation(&"idle") else (names[0] if names.size() > 0 else &"")
	return frames.get_frame_texture(anim, 0) if anim != &"" and frames.get_frame_count(anim) > 0 else null
