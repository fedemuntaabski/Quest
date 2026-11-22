extends Control

## Main menu (menu-33 look): the crypt illustration (MenuBackdrop: parallax, flicker,
## gem pulse, embers), a dark shade on the left, the QUEST title top-left and a column of
## stone plaques (UiStyles.style_plaque_button). Navigation lives in MainMenuFlow.

@onready var center_container: CenterContainer = $CenterContainer
@onready var main_vbox: VBoxContainer = $CenterContainer/VBoxContainer

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitMargin/ExitButton

@onready var options_menu: OptionsMenu = $OptionsMenu

@onready var profile_container: HBoxContainer = $ProfileContainer
@onready var profile_avatar: TextureRect = $ProfileContainer/Avatar
@onready var profile_name_label: Label = $ProfileContainer/NameLabel

@onready var background: MenuBackdrop = $Background
@onready var left_shade: TextureRect = $LeftShade
@onready var title_box: VBoxContainer = $TitleBox
@onready var title_label: Label = $TitleBox/QuestTitle
@onready var title_ornament: MenuOrnament = $TitleBox/TitleOrnament
@onready var tagline_label: Label = $TitleBox/Tagline
@onready var version_label: Label = $VersionLabel

@onready var click_sound: AudioStreamPlayer = $click
@onready var hover_sound: AudioStreamPlayer = $hover

const BUTTON_FONT_PX := 30

var flow: MainMenuFlow
## progresion-10: code-built copy of OptionsButton (style), opens CreditsPanel.
var credits_button: Button
## intro-tutorial-17: code-built copy of OptionsButton, under Start: plays the Tutorial.
var tutorial_button: Button
var _chrome_tween: Tween


func _ready() -> void:
	_apply_audio_settings()
	_add_credits_button()
	_add_tutorial_button()
	_apply_style()
	_connect_signals()
	_setup_profile()

	start_button.grab_focus()

	flow = MainMenuFlow.new()
	flow.setup(
		self,
		center_container,
		main_vbox,
		options_menu,
		click_sound,
		hover_sound,
		start_button
	)

	flow.build_slot_selector(start_button)
	flow.build_network_mode_select()
	flow.build_hero_select()

	if options_menu:
		options_menu.close(false)

	# Title + ornament + tagline + the main column hide while a sub-screen is open.
	center_container.visibility_changed.connect(_on_column_visibility_changed)
	_play_entrance()


func _menu_buttons() -> Array[Button]:
	return [start_button, tutorial_button, options_button, credits_button, exit_button]


func _apply_style() -> void:
	for btn in _menu_buttons():
		UiStyles.style_plaque_button(btn, btn == exit_button, BUTTON_FONT_PX)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = maxf(66.0, Accessibility.font(BUTTON_FONT_PX) * 2.1)
	UiStyles.style_menu_title(title_label, 132)
	title_label.add_theme_constant_override("outline_size", 8)
	title_ornament.align_left = true
	title_ornament.custom_minimum_size = Vector2(440, 18)
	UiStyles.style_menu_text(tagline_label, 24, Color(QuestPalette.PARCHMENT, 0.85))
	tagline_label.add_theme_color_override("font_outline_color", QuestPalette.INK)
	tagline_label.add_theme_constant_override("outline_size", 4)
	UiStyles.style_menu_text(version_label, 16, Color(QuestPalette.PARCHMENT, 0.55))
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	UiStyles.style_menu_text(profile_name_label, 20)


## Title drops in, then the plaques slide in from the left one after another.
func _play_entrance() -> void:
	await get_tree().process_frame  # containers lay the column out first
	if not is_inside_tree():
		return
	MenuTransitionFX.play_stagger_in(self, [title_label, title_ornament, tagline_label], Vector2(0, -18), 0.12, 0.6)
	MenuTransitionFX.play_stagger_in(self, _menu_buttons(), Vector2(-40, 0), 0.07, 0.38, 0.35)


func _on_column_visibility_changed() -> void:
	var shown := center_container.visible
	if _chrome_tween and _chrome_tween.is_valid():
		_chrome_tween.kill()
	_chrome_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_chrome_tween.set_ignore_time_scale(true)
	_chrome_tween.tween_property(title_box, "modulate:a", 1.0 if shown else 0.0, 0.3)
	_chrome_tween.tween_property(left_shade, "modulate:a", 1.0 if shown else 0.35, 0.3)


func _apply_audio_settings() -> void:
	var settings_mgr = _get_settings_manager()
	if settings_mgr:
		settings_mgr.apply_volume_to_player(click_sound, "click")
		settings_mgr.apply_volume_to_player(hover_sound, "hover")
		if not settings_mgr.volume_changed.is_connected(_on_volume_changed):
			settings_mgr.volume_changed.connect(_on_volume_changed)


func _get_settings_manager() -> Node:
	if Engine.has_singleton("SettingsManager"):
		return Engine.get_singleton("SettingsManager")
	var root := get_tree().root if get_tree() else null
	if root and root.has_node("SettingsManager"):
		return root.get_node("SettingsManager")
	return null


func _on_volume_changed(type: String, _linear_val: float, db_val: float) -> void:
	match type:
		"click":
			if click_sound:
				click_sound.volume_db = db_val
		"hover":
			if hover_sound:
				hover_sound.volume_db = db_val


func _setup_profile() -> void:
	var steam_mgr := ManagerLocator.get_steam_manager()
	if steam_mgr == null or not steam_mgr.is_steam_available():
		profile_container.visible = false
		return
	profile_name_label.text = SteamApi.steam().getPersonaName()
	steam_mgr.avatar_loaded_ready.connect(_on_avatar_loaded)
	if steam_mgr.avatar_cache.has(SteamApi.steam().getSteamID()):
		profile_avatar.texture = steam_mgr.avatar_cache[SteamApi.steam().getSteamID()]
	else:
		steam_mgr.get_user_avatar()


func _on_avatar_loaded(steam_id: int, texture: ImageTexture) -> void:
	if steam_id == SteamApi.steam().getSteamID():
		profile_avatar.texture = texture


func _connect_signals() -> void:
	for btn in _menu_buttons():
		if btn and not btn.mouse_entered.is_connected(_play_hover):
			btn.mouse_entered.connect(_play_hover)


func _add_credits_button() -> void:
	credits_button = options_button.duplicate(0) as Button
	credits_button.name = "CreditsButton"
	credits_button.text = "CRÉDITOS"
	main_vbox.add_child(credits_button)
	main_vbox.move_child(credits_button, options_button.get_index() + 1)
	credits_button.pressed.connect(open_credits)


func _add_tutorial_button() -> void:
	tutorial_button = options_button.duplicate(0) as Button
	tutorial_button.name = "TutorialButton"
	tutorial_button.text = "TUTORIAL"
	main_vbox.add_child(tutorial_button)
	main_vbox.move_child(tutorial_button, start_button.get_index() + 1)
	tutorial_button.pressed.connect(func() -> void:
		_play_click()
		if flow:
			flow.tutorial_pressed())


func open_credits() -> CreditsPanel:
	_play_click()
	var panel := CreditsPanel.new()
	panel.name = "CreditsPanel"
	add_child(panel)
	panel.closed.connect(func() -> void: credits_button.grab_focus())
	return panel


func _play_hover() -> void:
	if hover_sound and hover_sound.stream and not hover_sound.playing:
		hover_sound.play()


func _play_click() -> void:
	if click_sound and click_sound.stream:
		click_sound.play()


func on_start_button_pressed() -> void:
	_play_click()
	if flow:
		flow.start_pressed()


func _on_options_button_pressed() -> void:
	_play_click()
	if flow:
		flow.show_options_menu()


func on_exit_button_pressed() -> void:
	_play_click()
	if flow:
		flow.exit_pressed()
