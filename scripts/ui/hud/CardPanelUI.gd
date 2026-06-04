extends Control
class_name CardPanelUI

const CardPanelRowScene := preload("res://scenes/CardPanelRow.tscn")

@onready var cards_container: VBoxContainer = $ScrollContainer/VBoxContainer

var _card_entries: Array[CardDisplayData] = []
var _rows: Array[CardPanelRow] = []


# -------------------------
# PUBLIC API
# -------------------------

func refresh(cards_payload: Array[CardDisplayData]) -> void:
	if cards_payload == null:
		_card_entries.clear()
	else:
		_card_entries = cards_payload.duplicate()

	_update_display()


# -------------------------
# CORE UPDATE (DIFF + POOL)
# -------------------------

func _update_display() -> void:
	if cards_container == null:
		return

	var count := _card_entries.size()

	# 1. asegurar pool suficiente
	_ensure_pool_size(count)

	# 2. actualizar rows existentes
	for i in range(_rows.size()):
		var row := _rows[i]

		if i < count:
			var data := _card_entries[i]

			row.visible = true

			if data == null:
				row.setup_empty(i + 1)
			else:
				row.setup_card(i + 1, data)

		else:
			# sobran rows → ocultar
			row.visible = false


# -------------------------
# POOL MANAGEMENT
# -------------------------

func _ensure_pool_size(size: int) -> void:
	while _rows.size() < size:
		var row := CardPanelRowScene.instantiate() as CardPanelRow
		if row == null:
			return

		cards_container.add_child(row)
		_rows.append(row)


# -------------------------
# OPTIONAL CLEAR (soft reset)
# -------------------------

func clear() -> void:
	_card_entries.clear()

	for row in _rows:
		row.visible = false