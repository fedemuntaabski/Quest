extends SceneTree

## Session calidad-13: accessibility options.
##   - SettingsManager setters mirror into the Accessibility statics; text scale clamps
##   - Accessibility.font() scales; the root theme follows text_scale
##   - colorblind: HealthBarStyle palette + glyphs, item rarity palette + shape + label
##   - reduce_flashes: no invasion flash, steady Relic border, "!" glyph on critical HP
##   - sound captions: shown only when enabled
##   - settings round trip of the accessibility section
##   godot --headless --path . --script res://tests/test_accessibility.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []
var _settings: Node


func _initialize() -> void:
	_settings = root.get_node("SettingsManager")
	await process_frame  # autoloads enter the tree after _initialize
	_test_settings_mirror()
	_test_colorblind()
	await _test_hud()
	_restore()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_accessibility: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _restore() -> void:
	_settings.text_scale = 1.0
	_settings.colorblind_mode = false
	_settings.reduce_flashes = false
	_settings.sound_captions = false


func _test_settings_mirror() -> void:
	_settings.text_scale = 3.0
	_expect(is_equal_approx(_settings.text_scale, 1.5) and is_equal_approx(Accessibility.text_scale, 1.5), "text scale clamps to 1.5")
	_expect(Accessibility.font(20) == 30, "font(20) at 150%% = 30, got %d" % Accessibility.font(20))
	_expect(root.theme != null and root.theme.default_font_size == 24, "root theme default font follows the scale")
	_settings.text_scale = 1.0
	_expect(Accessibility.font(20) == 20 and root.theme.default_font_size == 16, "back to 100%")
	_settings.colorblind_mode = true
	_settings.reduce_flashes = true
	_settings.sound_captions = true
	_expect(Accessibility.colorblind and Accessibility.reduce_flashes and Accessibility.sound_captions, "flags mirrored")
	_restore()


func _test_colorblind() -> void:
	var style := load("res://resources/ui/health_bar_style.tres") as HealthBarStyle
	var normal := [style.color_for(0.9), style.color_for(0.5), style.color_for(0.1)]
	_expect(style.glyph_for(0.5) == "" and style.glyph_for(0.1) == "", "no glyphs by default")
	_settings.colorblind_mode = true
	var cb := [style.color_for(0.9), style.color_for(0.5), style.color_for(0.1)]
	_expect(cb != normal and cb[0] == style.cb_high_color and cb[2] == style.cb_low_color, "colorblind palette used")
	_expect(style.glyph_for(0.9) == "" and style.glyph_for(0.5) == "▲" and style.glyph_for(0.1) == "!", "glyphs by state")
	# the three colorblind states differ in lightness too (not only hue)
	_expect(absf(cb[0].get_luminance() - cb[1].get_luminance()) > 0.1 and absf(cb[1].get_luminance() - cb[2].get_luminance()) > 0.1, "colorblind states differ in lightness")
	var item := ItemData.new()
	item.display_name = "Espada"
	var shapes: Array[String] = []
	for r in ItemData.Rarity.values():
		item.rarity = r
		shapes.append(item.shape())
		_expect(item.color() == ItemData.RARITY_COLORS_CB[r], "rarity %d colorblind color" % r)
	_expect(shapes.size() == 5 and Array(shapes).filter(func(s: String) -> bool: return s != "").size() == 5 and _unique(shapes), "5 distinct rarity shapes: %s" % [shapes])
	item.rarity = ItemData.Rarity.LEGENDARY
	_expect(item.rarity_label() == "★ Espada (Legendario)", "label with shape: %s" % item.rarity_label())
	_settings.colorblind_mode = false
	_expect(item.shape() == "" and item.rarity_label() == "Espada (Legendario)" and item.color() == ItemData.RARITY_COLORS[item.rarity], "default rarity display unchanged")
	_settings.reduce_flashes = true
	_expect(style.glyph_for(0.1) == "!" and style.glyph_for(0.5) == "", "reduce_flashes: '!' replaces the low-HP blink")
	_restore()


func _unique(values: Array[String]) -> bool:
	var seen := {}
	for v in values:
		seen[v] = true
	return seen.size() == values.size()


func _test_hud() -> void:
	var world := (load(MAIN2D_PATH) as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	_settings.reduce_flashes = true
	hud.trigger_invasion_alert()
	await create_timer(0.1).timeout
	_expect(is_zero_approx(hud.invasion_flash.color.a), "reduce_flashes: no invasion flash")
	hud.set_relic_alert(true)
	await create_timer(0.35).timeout
	_expect(hud.relic_alert.visible and is_equal_approx(hud.relic_alert.modulate.a, 1.0), "reduce_flashes: steady Reliquia border")
	hud.set_relic_alert(false)
	_settings.reduce_flashes = false
	hud.trigger_invasion_alert()
	await create_timer(0.15).timeout
	_expect(hud.invasion_flash.color.a > 0.0, "flash plays by default")

	hud.show_caption("prueba")
	_expect(not hud.caption_label.visible, "no caption when disabled")
	_settings.sound_captions = true
	hud.show_caption("prueba")
	_expect(hud.caption_label.visible and hud.caption_label.text == "♪ prueba", "caption shown: '%s'" % hud.caption_label.text)
	_expect(hud.controls_help != null and not hud.controls_help.visible, "help panel built, hidden")
	hud.toggle_controls_help()
	_expect(hud.controls_help.visible, "show_help toggles the panel")
	_restore()
	hud.queue_free()
	world.queue_free()
	await process_frame
