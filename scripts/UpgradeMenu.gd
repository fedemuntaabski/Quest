extends CanvasLayer

signal upgrade_chosen(upgrade: Dictionary)
signal upgrade_replaced(old_upgrade: Dictionary, new_upgrade: Dictionary)
signal upgrade_skipped()

const OPTIONS_COUNT := 3

const UPGRADE_POOL: Array[Dictionary] = [
	{card_name="Steel Edge", description="Hone your blade.", stat_affected="strength", value_change=2, rarity="common"},
	{card_name="Shadowstep", description="Move unseen.", stat_affected="dexterity", value_change=2, rarity="common"},
	{card_name="Arcane Flux", description="Magic flows.", stat_affected="magic", value_change=2, rarity="common"},

	{card_name="Battle Fury", description="Controlled rage.", stat_affected="strength", value_change=3, rarity="rare"},
	{card_name="Phantom Feet", description="Too fast to see.", stat_affected="dexterity", value_change=3, rarity="rare"},

	{card_name="Blood Pact", description="Power at cost.", stat_affected="magic", value_change=5, rarity="cursed", secondary_stat="hp", secondary_change=-2},
]

var _bg: ColorRect
var _panel: PanelContainer
var _buttons: Array[Button] = []

var _options: Array[Dictionary] = []
var _pending_upgrade: Dictionary = {}
var _selecting_sacrifice := false

@onready var card_container: CardContainer = get_node_or_null("/root/CardContainer")


# ─────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 10
	_build_ui()
	visible = false


# ─────────────────────────────────────────────
# UI
# ─────────────────────────────────────────────

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.65)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(700, 320)
	add_child(_panel)

	var root := VBoxContainer.new()
	_panel.add_child(root)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hbox)

	for i in range(OPTIONS_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 220)
		b.pressed.connect(_on_pick.bind(i))
		hbox.add_child(b)
		_buttons.append(b)

	var skip := Button.new()
	skip.text = "No tomar"
	skip.pressed.connect(_skip)
	root.add_child(skip)


# ─────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────

func show_menu(_room_id: int) -> void:
	_options = _generate_options()
	_refresh_ui()

	visible = true
	get_tree().paused = true


# ─────────────────────────────────────────────
# UI UPDATE
# ─────────────────────────────────────────────

func _refresh_ui() -> void:
	for i in range(_buttons.size()):
		var b: Button = _buttons[i]
		var o: Dictionary = _options[i]

		b.text = "%s\n\n%s\n\n+%d %s" % [
			o.get("card_name", ""),
			o.get("description", ""),
			int(o.get("value_change", 0)),
			o.get("stat_affected", "")
		]


# ─────────────────────────────────────────────
# PICK UPGRADE
# ─────────────────────────────────────────────

func _on_pick(i: int) -> void:
	if i >= _options.size():
		return

	_pending_upgrade = _options[i]

	if card_container == null:
		push_warning("No CardContainer")
		return

	# CASO 1: espacio libre
	if not card_container.is_full():
		card_container.add_card(_pending_upgrade)
		upgrade_chosen.emit(_pending_upgrade)
		close_menu()
		return

	# CASO 2: lleno → elegir sacrificio
	_enter_sacrifice_mode()


# ─────────────────────────────────────────────
# SACRIFICE MODE
# ─────────────────────────────────────────────

func _enter_sacrifice_mode() -> void:
	_selecting_sacrifice = true

	# reusar botones para mostrar cartas actuales
	var cards: Array = card_container.get_all_cards()

	for i in range(_buttons.size()):
		var b: Button = _buttons[i]

		if i < cards.size():
			var c: Dictionary = cards[i]
			b.text = "[SACRIFICAR]\n%s\n\n%s" % [
				c.get("card_name", ""),
				c.get("description", "")
			]
			for conn in b.pressed.get_connections():
				b.pressed.disconnect(conn.callable)
			b.pressed.connect(_on_sacrifice.bind(i))
		else:
			b.text = ""
			b.disabled = true


# ─────────────────────────────────────────────

func _on_sacrifice(i: int) -> void:
	if not _selecting_sacrifice:
		return

	var removed: Dictionary = card_container.get_card(i)

	card_container.remove_card(i)
	card_container.add_card(_pending_upgrade)

	upgrade_replaced.emit(removed, _pending_upgrade)

	close_menu()


# ─────────────────────────────────────────────

func _skip() -> void:
	upgrade_skipped.emit()
	close_menu()


func close_menu() -> void:
	_selecting_sacrifice = false
	visible = false
	get_tree().paused = false


# ─────────────────────────────────────────────
# GENERATION (igual que antes)
# ─────────────────────────────────────────────

func _generate_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	while result.size() < OPTIONS_COUNT:
		var u: Dictionary = _weighted_pick()
		if not result.has(u):
			result.append(u)

	return result


func _weighted_pick() -> Dictionary:
	var roll := randi_range(0, 100)

	var rarity := "common"
	if roll < 60:
		rarity = "common"
	elif roll < 90:
		rarity = "rare"
	else:
		rarity = "cursed"

	var pool: Array[Dictionary] = []
	for u in UPGRADE_POOL:
		if u.get("rarity") == rarity:
			pool.append(u)

	return pool[randi() % pool.size()]