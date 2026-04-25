extends CanvasLayer

## UpgradeMenu — Roguelite card-pick overlay
##
## Shown automatically when DungeonGenerator emits room_cleared.
## Pauses the scene tree while visible; the room timer freezes naturally.
##
## Wiring (done in Main2d._ready):
##   dungeon_generator.room_cleared.connect(upgrade_menu.show_menu)
##   upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)

signal upgrade_chosen(upgrade: Dictionary)

# ─────────────────────────────────────────────────────────────────────────────
# Upgrade pool — 15 entries
# stat_affected values: "strength" | "magic" | "dexterity" | "hp"
# rarity values:        "common" (60) | "rare" (30) | "cursed" (10)
# ─────────────────────────────────────────────────────────────────────────────
const UPGRADE_POOL: Array = [
	# ── Common ────────────────────────────────────────────────────────────────
	{card_name="Steel Edge",     description="Hone your blade — violence, perfected.",
	 stat_affected="strength",  value_change=2,  rarity="common"},
	{card_name="Shadowstep",     description="Your feet forget the floor.",
	 stat_affected="dexterity", value_change=2,  rarity="common"},
	{card_name="Arcane Flux",    description="A current of raw magic courses through you.",
	 stat_affected="magic",     value_change=2,  rarity="common"},
	{card_name="Iron Will",      description="Pain is merely inconvenient.",
	 stat_affected="hp",        value_change=4,  rarity="common"},

	# ── Rare ──────────────────────────────────────────────────────────────────
	{card_name="Battle Fury",    description="Rage tempered into lethal precision.",
	 stat_affected="strength",  value_change=3,  rarity="rare"},
	{card_name="Phantom Feet",   description="You move before thought catches up.",
	 stat_affected="dexterity", value_change=3,  rarity="rare"},
	{card_name="Void Surge",     description="Reality bends to your will.",
	 stat_affected="magic",     value_change=3,  rarity="rare"},
	{card_name="Vital Surge",    description="The dungeon bleeds life into your veins.",
	 stat_affected="hp",        value_change=6,  rarity="rare"},
	{card_name="Twin Fangs",     description="Strike twice where once was enough.",
	 stat_affected="strength",  value_change=4,  rarity="rare"},
	{card_name="Mystic Veil",    description="Spells coalesce from the dark.",
	 stat_affected="magic",     value_change=4,  rarity="rare"},

	# ── Cursed ────────────────────────────────────────────────────────────────
	{card_name="Cursed Blade",   description="Power at a price you haven't counted yet.",
	 stat_affected="strength",  value_change=5,  rarity="cursed"},
	{card_name="Blood Pact",     description="Sell years for moments of brilliance. (+5 MAG, −2 HP)",
	 stat_affected="magic",     value_change=5,  rarity="cursed",
	 secondary_stat="hp",       secondary_change=-2},
	{card_name="Dark Mirror",    description="You become the shadow hunting you.",
	 stat_affected="dexterity", value_change=5,  rarity="cursed"},
	{card_name="Eldritch Echo",  description="Magic that whispers back, louder each time.",
	 stat_affected="magic",     value_change=5,  rarity="cursed"},
	{card_name="Shattered Glass",description="Blinding speed, brittle frame. (+6 DEX, −3 HP)",
	 stat_affected="dexterity", value_change=6,  rarity="cursed",
	 secondary_stat="hp",       secondary_change=-3},
]

# Rarity weights (must sum to 100 for clarity, but any ratio works)
const WEIGHT_COMMON:  int = 60
const WEIGHT_RARE:    int = 30
const WEIGHT_CURSED:  int = 10

# ─────────────────────────────────────────────────────────────────────────────
# Rarity colour accents
const COLOR_COMMON:  Color = Color(0.85, 0.85, 0.78, 1.0)   # warm white
const COLOR_RARE:    Color = Color(0.50, 0.78, 1.00, 1.0)   # steel blue
const COLOR_CURSED:  Color = Color(0.80, 0.35, 1.00, 1.0)   # violet

# ─────────────────────────────────────────────────────────────────────────────
# Node references — built procedurally in _ready so no .tscn is required
# for the inner UI, but the CanvasLayer itself lives in UpgradeMenu.tscn.
var _bg_rect:       ColorRect
var _panel:         PanelContainer
var _title:         Label
var _card_buttons:  Array[Button] = []
var _pending_upgrades: Array = []   # the 3 cards currently on display

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 10
	visible = false
	_build_ui()
	print("UpgradeMenu: ready.")

# ─────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# ── Dark overlay ──────────────────────────────────────────────────────────
	_bg_rect = ColorRect.new()
	_bg_rect.name = "BgRect"
	_bg_rect.color = Color(0.0, 0.0, 0.0, 0.0)   # starts transparent; tweened in
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(_bg_rect)

	# ── Parchment panel ───────────────────────────────────────────────────────
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.20, 0.15, 0.10, 0.96)   # dark parchment
	style.border_width_top    = 3
	style.border_width_bottom = 3
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_color        = Color(0.78, 0.62, 0.35, 1.0)    # gold border
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_top    = 32.0
	style.content_margin_bottom = 32.0
	style.content_margin_left   = 40.0
	style.content_margin_right  = 40.0
	_panel.add_theme_stylebox_override("panel", style)

	# Centre the panel (600 × 420 px)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(840, 420)
	_panel.position = Vector2(-420, -210)   # offset from centre anchor
	add_child(_panel)

	# ── Inner VBox ────────────────────────────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)

	# Title
	_title = Label.new()
	_title.name = "Title"
	_title.text = "✦  CHOOSE YOUR BOON  ✦"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.50, 1.0))
	_title.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	vbox.add_child(_title)

	# Subtitle / rarity hint
	var subtitle := Label.new()
	subtitle.text = "Kill the room, earn a boon."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.55, 0.40, 1.0))
	subtitle.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	vbox.add_child(subtitle)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.78, 0.62, 0.35, 0.5))
	sep.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	vbox.add_child(sep)

	# Card row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	hbox.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	vbox.add_child(hbox)

	for i in range(3):
		var card := _make_card_button(i)
		hbox.add_child(card)
		_card_buttons.append(card)

# ─────────────────────────────────────────────────────────────────────────────
func _make_card_button(slot_index: int) -> Button:
	var btn := Button.new()
	btn.name = "Card_%d" % slot_index
	btn.custom_minimum_size = Vector2(220, 240)
	btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	btn.pressed.connect(_on_card_pressed.bind(slot_index))
	btn.mouse_entered.connect(_on_card_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_card_hover.bind(btn, false))

	# Flat card style
	var normal := StyleBoxFlat.new()
	normal.bg_color        = Color(0.14, 0.10, 0.07, 0.95)
	normal.border_width_top    = 2
	normal.border_width_bottom = 2
	normal.border_width_left   = 2
	normal.border_width_right  = 2
	normal.border_color    = Color(0.78, 0.62, 0.35, 0.6)
	normal.corner_radius_top_left     = 8
	normal.corner_radius_top_right    = 8
	normal.corner_radius_bottom_left  = 8
	normal.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color        = Color(0.22, 0.17, 0.11, 0.97)
	hover.border_width_top    = 2
	hover.border_width_bottom = 2
	hover.border_width_left   = 2
	hover.border_width_right  = 2
	hover.border_color    = Color(0.95, 0.82, 0.50, 1.0)
	hover.corner_radius_top_left     = 8
	hover.corner_radius_top_right    = 8
	hover.corner_radius_bottom_left  = 8
	hover.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80, 1.0))
	btn.add_theme_font_size_override("font_size", 13)

	return btn

# ─────────────────────────────────────────────────────────────────────────────
func _on_card_hover(btn: Button, entered: bool) -> void:
	var tween := create_tween()
	var target_scale := Vector2(1.04, 1.04) if entered else Vector2.ONE
	tween.tween_property(btn, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE)

# ─────────────────────────────────────────────────────────────────────────────
## Called by Main2d when dungeon_generator emits room_cleared.
func show_menu(room_id: int) -> void:
	print("UpgradeMenu: showing for room %d" % room_id)
	_pending_upgrades = _pick_weighted_cards()
	_populate_cards()

	visible = true
	get_tree().paused = true

	# Fade in: overlay then panel
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bg_rect,  "color",     Color(0.0, 0.0, 0.0, 0.65), 0.40).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_panel,    "modulate",  Color(1, 1, 1, 1),           0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_panel,    "position:y", _panel.position.y,          0.45).from(_panel.position.y + 30.0).set_trans(Tween.TRANS_BACK)

# ─────────────────────────────────────────────────────────────────────────────
func _populate_cards() -> void:
	for i in range(_card_buttons.size()):
		var btn: Button    = _card_buttons[i]
		var upg: Dictionary = _pending_upgrades[i]

		var rarity_str: String = upg.get("rarity", "common")
		var rarity_color: Color = _rarity_color(rarity_str)
		var delta: int = upg.get("value_change", 0)
		var stat_label: String = _stat_display_name(upg.get("stat_affected", ""))

		var suffix := ""
		if upg.has("secondary_stat"):
			var sec_d: int = upg.get("secondary_change", 0)
			suffix = "\n%+d %s" % [sec_d, _stat_display_name(upg.get("secondary_stat", ""))]

		btn.text = (
			"[%s]\n\n%s\n\n%+d %s%s\n\n\"%s\""
			% [
				rarity_str.to_upper(),
				upg.get("card_name", "???"),
				delta, stat_label,
				suffix,
				upg.get("description", "")
			]
		)
		btn.add_theme_color_override("font_color", rarity_color)
		# Reset scale/modulate for fresh animation
		btn.modulate = Color(1, 1, 1, 0)
		btn.scale    = Vector2(0.9, 0.9)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.30 + i * 0.08).set_trans(Tween.TRANS_SINE)
		tween.tween_property(btn, "scale",    Vector2.ONE,        0.30 + i * 0.08).set_trans(Tween.TRANS_BACK)

# ─────────────────────────────────────────────────────────────────────────────
func _on_card_pressed(slot_index: int) -> void:
	if slot_index >= _pending_upgrades.size():
		return
	var chosen: Dictionary = _pending_upgrades[slot_index]
	print("UpgradeMenu: player chose '%s'" % chosen.get("card_name", "???"))

	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats:
		player_stats.apply_upgrade(chosen)

	# Apply secondary stat if present (e.g. Blood Pact, Shattered Glass)
	if chosen.has("secondary_stat"):
		var secondary: Dictionary = {
			card_name    = chosen.get("card_name", ""),
			stat_affected = chosen.get("secondary_stat", ""),
			value_change  = chosen.get("secondary_change", 0),
		}
		if player_stats:
			player_stats.apply_upgrade(secondary)

	upgrade_chosen.emit(chosen)
	close_menu()

# ─────────────────────────────────────────────────────────────────────────────
func close_menu() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bg_rect, "color",    Color(0.0, 0.0, 0.0, 0.0), 0.30)
	tween.tween_property(_panel,   "modulate", Color(1, 1, 1, 0.0),        0.25)
	await tween.finished
	visible = false
	get_tree().paused = false

# ─────────────────────────────────────────────────────────────────────────────
## Weighted random picker — returns 3 distinct upgrades.
func _pick_weighted_cards() -> Array:
	var result: Array = []
	var used_names: Array = []

	var max_attempts := 200
	while result.size() < 3 and max_attempts > 0:
		max_attempts -= 1
		var candidate: Dictionary = _weighted_random_upgrade()
		if candidate.is_empty():
			break
		if candidate.get("card_name", "") in used_names:
			continue
		used_names.append(candidate.get("card_name", ""))
		result.append(candidate)

	# Safety fallback: fill with first unused entries
	if result.size() < 3:
		for upg in UPGRADE_POOL:
			if result.size() >= 3:
				break
			if upg.get("card_name", "") not in used_names:
				result.append(upg)
				used_names.append(upg.get("card_name", ""))

	return result

# ─────────────────────────────────────────────────────────────────────────────
## Draw one upgrade using weighted rarity.
func _weighted_random_upgrade() -> Dictionary:
	var total_weight := WEIGHT_COMMON + WEIGHT_RARE + WEIGHT_CURSED
	var roll := randi_range(0, total_weight - 1)

	var target_rarity: String
	if roll < WEIGHT_COMMON:
		target_rarity = "common"
	elif roll < WEIGHT_COMMON + WEIGHT_RARE:
		target_rarity = "rare"
	else:
		target_rarity = "cursed"

	# Build a filtered pool for the chosen rarity
	var pool: Array = []
	for upg in UPGRADE_POOL:
		if upg.get("rarity", "") == target_rarity:
			pool.append(upg)

	if pool.is_empty():
		return {}

	return pool[randi() % pool.size()]

# ─────────────────────────────────────────────────────────────────────────────
func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":  return COLOR_COMMON
		"rare":    return COLOR_RARE
		"cursed":  return COLOR_CURSED
		_:         return COLOR_COMMON

func _stat_display_name(stat: String) -> String:
	match stat:
		"strength":  return "STR"
		"magic":     return "MAG"
		"dexterity": return "DEX"
		"hp":        return "HP"
		_:           return stat.to_upper()
