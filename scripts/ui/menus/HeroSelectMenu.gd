extends Control
class_name HeroSelectMenu

## HeroSelectMenu — single-player party pick (session 13): exactly PARTY_SIZE of
## the CharacterDatabase heroes, DotE-style. Left: hero cards. Right: preview of
## the highlighted hero (idle animation, Nearest) + stats. Below: the chosen slots.
## MainMenuFlow opens it between slot selection and the game scene.
## UI is code-built (like the HUD); the .tscn is just the root Control.

signal heroes_confirmed(hero_ids: Array[String])
signal back_pressed

const PARTY_SIZE := preload("res://scripts/autoload/GameSession.gd").PARTY_SIZE
## Pixel art (16 px tiles) shown big; integer scale keeps it crisp.
const PREVIEW_SCALE := 6.0
const PREMISE := "El señor demonio saqueó la abadía y hundió sus cinco reliquias en las profundidades.
Recuperalas: cada una que toques despertará a la mazmorra."
## menu-33: the armoury illustration (two braziers) behind the pick.
const BACKGROUND := preload("res://assets/ui/menu_armeria.png")
const BACKGROUND_FLAMES := [Vector3(0.227, 0.457, 0.085), Vector3(0.76, 0.468, 0.085)]
const TITLE_FONT := UiStyles.TITLE_FONT
const UI_FONT := UiStyles.UI_FONT

var start_button: Button
var back_button: Button
## Chosen hero ids, in pick order (= party order).
var selected: Array[String] = []

var _click_sound: AudioStreamPlayer
var _hover_sound: AudioStreamPlayer
var _active_tween: Tween = null
var _is_animating_open: bool = false
var _cards: Dictionary = {}  # hero_id → Button
var _card_names: Dictionary = {}  # hero_id → Label
var _slots: Array[Button] = []
var _preview_holder: Control
var _preview_sprite: AnimatedSprite2D
var _preview_name: Label
var _preview_info: Label
var _hint: Label
var _preview_id: String = ""


func setup(click_sound: AudioStreamPlayer = null, hover_sound: AudioStreamPlayer = null) -> void:
	_click_sound = click_sound
	_hover_sound = hover_sound


func _ready() -> void:
	_build_ui()
	_refresh()
	var heroes := CharacterDatabase.get_all()
	if not heroes.is_empty():
		_show_preview(heroes[0].character_id)


## Adds the hero, or removes it if already chosen. A third pick is refused.
func toggle_hero(hero_id: String) -> bool:
	if selected.has(hero_id):
		selected.erase(hero_id)
	elif selected.size() >= PARTY_SIZE:
		_hint.text = "Ya elegiste %d héroes: quitá uno primero." % PARTY_SIZE
		return false
	else:
		selected.append(hero_id)
	_refresh()
	return true


func can_start() -> bool:
	return selected.size() == PARTY_SIZE


# ---------------- UI ----------------

func _build_ui() -> void:
	var bg := MenuBackdrop.new()
	bg.name = "Backdrop"
	bg.texture = BACKGROUND
	bg.flames = PackedVector3Array(BACKGROUND_FLAMES)
	bg.tint = Color(0.01, 0.02, 0.03, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	margin.add_child(main)

	var title := Label.new()
	title.text = "ELEGÍ TUS %d HÉROES" % PARTY_SIZE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyles.style_menu_title(title, 34)
	main.add_child(title)
	var ornament := UiStyles.make_ornament()
	ornament.custom_minimum_size = Vector2(420, 10)
	ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main.add_child(ornament)

	var premise := Label.new()
	premise.text = PREMISE
	premise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyles.style_menu_text(premise, 18, Color(QuestPalette.PARCHMENT, 0.9))
	premise.add_theme_color_override("font_outline_color", QuestPalette.INK)
	premise.add_theme_constant_override("outline_size", 3)
	main.add_child(premise)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 28)
	main.add_child(content)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 3.0
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	content.add_child(grid)
	for data in CharacterDatabase.get_all():
		grid.add_child(_build_card(data))

	content.add_child(_build_preview_panel())

	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 20)
	main.add_child(slots_row)
	for i in PARTY_SIZE:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(300, 72)
		slot.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot.expand_icon = true
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		UiStyles.style_plaque_button(slot, false, 20, false)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slots_row.add_child(slot)
		_slots.append(slot)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyles.style_menu_text(_hint, 17, QuestPalette.RELIC_GOLD)
	_hint.add_theme_color_override("font_outline_color", QuestPalette.INK)
	_hint.add_theme_constant_override("outline_size", 3)
	main.add_child(_hint)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	main.add_child(buttons)
	back_button = _make_action_button("VOLVER", 22)
	back_button.pressed.connect(_on_back_pressed)
	buttons.add_child(back_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	buttons.add_child(_build_difficulty_row())
	var spacer_2 := Control.new()
	spacer_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer_2)
	start_button = _make_action_button("COMENZAR", 26)
	start_button.pressed.connect(_on_start_pressed)
	buttons.add_child(start_button)


## progresion-10: Normal / Difícil toggles (DifficultyConfig), stored in
## GameSession.difficulty when picked; the run reads it from there.
var difficulty_buttons: Dictionary = {}


func _build_difficulty_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.text = "Dificultad:"
	UiStyles.style_menu_text(label, 18, QuestPalette.PARCHMENT)
	label.add_theme_color_override("font_outline_color", QuestPalette.INK)
	label.add_theme_constant_override("outline_size", 3)
	row.add_child(label)
	var session := ManagerLocator.get_game_session()
	var current: String = session.difficulty if session else "normal"
	var group := ButtonGroup.new()
	var config := DifficultyConfig.get_default()
	for level in (config.levels if config else []):
		var btn := _make_action_button(level.display_name.to_upper(), 20, false)
		btn.custom_minimum_size = Vector2(140, 48)
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = level.id == current
		btn.tooltip_text = level.description
		btn.pressed.connect(set_difficulty.bind(level.id))
		row.add_child(btn)
		difficulty_buttons[level.id] = btn
	return row


func set_difficulty(id: String) -> void:
	var session := ManagerLocator.get_game_session()
	if session:
		session.difficulty = id
	if difficulty_buttons.has(id):
		(difficulty_buttons[id] as Button).set_pressed_no_signal(true)
	_play_click()


func _build_card(data: CharacterData) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(210, 170)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_entered.connect(_on_card_hover.bind(data.character_id))
	card.focus_entered.connect(_show_preview.bind(data.character_id))
	card.pressed.connect(_on_card_pressed.bind(data.character_id))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 10
	box.offset_bottom = -10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var portrait := TextureRect.new()
	portrait.texture = _portrait_of(data)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait)

	var name_label := Label.new()
	name_label.text = data.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyles.style_menu_text(name_label, 22, QuestPalette.PARCHMENT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	_cards[data.character_id] = card
	_card_names[data.character_id] = name_label
	return card


func _build_preview_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 2.0
	UiStyles.style_menu_frame(panel, 8)

	var pad := MarginContainer.new()  # visual-24: the stats sat flush on the panel's left edge
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	pad.add_child(box)

	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 240)
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.resized.connect(_center_preview)
	box.add_child(_preview_holder)

	_preview_sprite = AnimatedSprite2D.new()
	_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_sprite.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_preview_holder.add_child(_preview_sprite)

	_preview_name = Label.new()
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyles.style_menu_title(_preview_name, 28)
	box.add_child(_preview_name)

	_preview_info = Label.new()
	_preview_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyles.style_menu_text(_preview_info, 17, QuestPalette.PARCHMENT_LIGHT)
	box.add_child(_preview_info)
	return panel


func _make_action_button(text: String, font_size: int, marker: bool = true) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 60)
	btn.mouse_entered.connect(_play_hover)
	UiStyles.style_plaque_button(btn, false, font_size, marker)
	return btn


## Idle sprite frame (same art as the HUD portrait) > portrait PNG.
func _portrait_of(data: CharacterData) -> Texture2D:
	var frames := data.sprite_frames
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		return frames.get_frame_texture("idle", 0)
	return data.portrait


# ---------------- STATE → VIEW ----------------

func _refresh() -> void:
	for id: String in _cards:
		var picked := selected.has(id)
		var card: Button = _cards[id]
		card.add_theme_stylebox_override("normal", UiStyles.build_card_style("picked" if picked else "normal"))
		for state in ["hover", "pressed", "hover_pressed"]:
			card.add_theme_stylebox_override(state, UiStyles.build_card_style("picked" if picked else "hot"))
		card.add_theme_stylebox_override("focus", UiStyles.build_plaque_style("focus"))
		(_card_names[id] as Label).add_theme_color_override("font_color", QuestPalette.RELIC_GOLD_PALE if picked else QuestPalette.PARCHMENT)
		var data := CharacterDatabase.get_by_id(id)
		(_card_names[id] as Label).text = "%s  [%d]" % [data.display_name, selected.find(id) + 1] if picked else data.display_name
	for i in _slots.size():
		var slot := _slots[i]
		if i < selected.size():
			var data := CharacterDatabase.get_by_id(selected[i])
			slot.text = "%d. %s" % [i + 1, data.display_name]
			slot.icon = _portrait_of(data)
			slot.tooltip_text = "Clic para quitar"
		else:
			slot.text = "%d. — vacío —" % (i + 1)
			slot.icon = null
			slot.tooltip_text = ""
	_hint.text = "" if can_start() else "Elegí %d héroes distintos (%d/%d)." % [PARTY_SIZE, selected.size(), PARTY_SIZE]
	if start_button:
		start_button.disabled = _is_animating_open or not can_start()


func _show_preview(hero_id: String) -> void:
	if hero_id == _preview_id or _preview_sprite == null:
		return
	_preview_id = hero_id
	var data := CharacterDatabase.get_by_id(hero_id)
	var frames := data.sprite_frames
	_preview_sprite.sprite_frames = frames
	if frames:
		var anim: StringName = &"idle" if frames.has_animation("idle") else frames.get_animation_names()[0]
		_preview_sprite.play(anim)
	_preview_name.text = "%s — %s" % [data.display_name, data.role] if data.role != "" else data.display_name
	_preview_info.text = "Vida: %d\nAtaque: %d\nIntervalo: %.1f s\n\nPasiva — %s\n%s\n\nActiva — %s\n%s" % [
		data.base_hp, data.attack_damage, data.attack_interval,
		data.passive_ability_name, _ability_text(data.passive, data.passive_ability_desc),
		data.active_ability_name, _ability_text(data.active, ""),
	]
	_center_preview()


## juego-35: the ability's own text with its numbers (value, duration, cooldown), as
## the hero sheet shows it; `fallback` when the .tres has none.
static func _ability_text(ability: AbilityData, fallback: String) -> String:
	return ability.format_description() if ability and ability.description != "" else fallback


func _center_preview() -> void:
	if _preview_holder and _preview_sprite:
		_preview_sprite.position = _preview_holder.size * 0.5


# ---------------- INPUT ----------------

func _on_card_hover(hero_id: String) -> void:
	_play_hover()
	_show_preview(hero_id)


func _on_card_pressed(hero_id: String) -> void:
	_show_preview(hero_id)
	toggle_hero(hero_id)
	_play_click()


func _on_slot_pressed(index: int) -> void:
	if index < selected.size():
		toggle_hero(selected[index])
		_play_click()


func _on_start_pressed() -> void:
	if not can_start():
		return
	_play_click()
	heroes_confirmed.emit(selected.duplicate())


func _on_back_pressed() -> void:
	_play_click()
	back_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not back_button.disabled:
		get_viewport().set_input_as_handled()
		_on_back_pressed()


# ---------------- OPEN / CLOSE ----------------

func open() -> void:
	if visible and _is_animating_open:
		return

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	selected.clear()
	visible = true
	_is_animating_open = true
	_refresh()
	back_button.disabled = true

	_active_tween = MenuTransitionFX.play_entrance(
		self,
		[{"node": self, "max_alpha": 1.0}],
		[],
		0.28, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, Vector2(0.93, 0.93)
	)
	if _active_tween != null:
		await _active_tween.finished

	_is_animating_open = false
	back_button.disabled = false
	_refresh()
	var first: Button = _cards.get(CharacterDatabase.get_default_id())
	if first:
		first.grab_focus()


func close(animate: bool = true) -> void:
	if not visible:
		return

	_is_animating_open = false

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	if not animate:
		visible = false
		return

	back_button.disabled = true
	start_button.disabled = true

	_active_tween = MenuTransitionFX.play_exit(
		self,
		[{"node": self, "max_alpha": 1.0}],
		[],
		0.28, Vector2(0.93, 0.93),
		Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
	)
	if _active_tween != null:
		await _active_tween.finished

	visible = false


func _play_click() -> void:
	if _click_sound and _click_sound.stream:
		_click_sound.play()


func _play_hover() -> void:
	if _hover_sound and _hover_sound.stream and not _hover_sound.playing:
		_hover_sound.play()
