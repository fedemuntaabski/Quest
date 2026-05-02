extends HBoxContainer
class_name CardContainer

const MAX_EQUIPPED_CARDS: int = 5

var equipped_cards: Array[Dictionary] = []

signal cards_changed(cards: Array)
signal card_hovered(card: Dictionary)
signal card_drag_preview(from_card: Dictionary, to_card: Dictionary)
signal card_absorbed(card: Dictionary)

# Debug hook (lo conectás desde Main)
signal debug_open_requested()

func _ready() -> void:
	custom_minimum_size = Vector2(500, 200)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)

	_create_debug_button()

# ─────────────────────────────────────────────
# CORE API
# ─────────────────────────────────────────────

func add_card(card: Dictionary) -> bool:
	if is_full():
		return false

	equipped_cards.append(card)
	_emit_change()
	_play_absorb_animation(card)
	return true


func remove_card(index: int) -> Dictionary:
	if index < 0 or index >= equipped_cards.size():
		return {}

	var removed := equipped_cards[index]
	equipped_cards.remove_at(index)

	_emit_change()
	return removed


func replace_card(index: int, new_card: Dictionary) -> Dictionary:
	var old := remove_card(index)
	add_card(new_card)
	return old


func get_card(index: int) -> Dictionary:
	if index >= 0 and index < equipped_cards.size():
		return equipped_cards[index]
	return {}


func get_all_cards() -> Array[Dictionary]:
	return equipped_cards.duplicate()


func is_full() -> bool:
	return equipped_cards.size() >= MAX_EQUIPPED_CARDS


func get_card_count() -> int:
	return equipped_cards.size()

# ─────────────────────────────────────────────
# DRAG & DROP SYSTEM
# ─────────────────────────────────────────────

func start_drag(index: int) -> Dictionary:
	return {
		"index": index,
		"card": get_card(index)
	}


func handle_drop(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return

	var temp := equipped_cards[from_index]
	equipped_cards[from_index] = equipped_cards[to_index]
	equipped_cards[to_index] = temp

	_emit_change()


func sacrifice_card(index: int) -> Dictionary:
	return remove_card(index)

# ─────────────────────────────────────────────
# LIVE COMPARISON (para UI hover)
# ─────────────────────────────────────────────

func request_preview(from_card: Dictionary, to_card: Dictionary) -> void:
	card_drag_preview.emit(from_card, to_card)

# ─────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────

func _emit_change() -> void:
	cards_changed.emit(equipped_cards)


func _play_absorb_animation(card: Dictionary) -> void:
	# Hook para VFX (shader / tween / particles)
	card_absorbed.emit(card)

# ─────────────────────────────────────────────
# DEBUG BUTTON
# ─────────────────────────────────────────────

func _create_debug_button() -> void:
	var btn := Button.new()
	btn.text = "DEBUG CARDS"
	btn.position = Vector2(10, -40)
	btn.pressed.connect(func():
		debug_open_requested.emit()
		print("--- DEBUG CARD CONTAINER ---")
		for c in equipped_cards:
			print(c)
	)
	add_child(btn)

# ─────────────────────────────────────────────
# UTIL
# ─────────────────────────────────────────────

func clear_cards() -> void:
	equipped_cards.clear()
	_emit_change()