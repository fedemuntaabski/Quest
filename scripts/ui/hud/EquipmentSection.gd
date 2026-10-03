extends VBoxContainer
class_name EquipmentSection

## EquipmentSection: "Equipo" block of CharacterPopup. The hero's slots (weapon,
## armor, relic, 2 consumables) over the party stash grid. Click only (no drag):
## stash item -> PartyInventory.equip (the reason shows in red when refused),
## equipped item -> unequip, "Usar" -> InventoryComponent.use. The UI decides
## nothing: PartyInventory.can_equip/can_unequip and InventoryComponent
## .get_block_reason give the verdict and the text. Refreshes on the inventory's
## signals; built in code, `bind()` before the popup shows it.

const CELL := Vector2(44, 44)
const STASH_COLUMNS := 8
const SLOT_ORDER: Array[ItemData.Slot] = [ItemData.Slot.WEAPON, ItemData.Slot.ARMOR, ItemData.Slot.RELIC, ItemData.Slot.CONSUMABLE]

var hero_id: String = ""

var _slots_row: HBoxContainer
var _bonus_label: Label
var _stash_title: Label
var _stash_grid: GridContainer
var _message: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 8)
	add_child(_slots_row)
	_bonus_label = Label.new()
	_bonus_label.add_theme_color_override("font_color", QuestPalette.PARCHMENT_LIGHT)
	_bonus_label.add_theme_font_size_override("font_size", 13)
	add_child(_bonus_label)
	_stash_title = Label.new()
	_stash_title.add_theme_color_override("font_color", QuestPalette.GOLD_LIGHT)
	add_child(_stash_title)
	_stash_grid = GridContainer.new()
	_stash_grid.columns = STASH_COLUMNS
	_stash_grid.add_theme_constant_override("h_separation", 4)
	_stash_grid.add_theme_constant_override("v_separation", 4)
	add_child(_stash_grid)
	_message = Label.new()
	_message.add_theme_color_override("font_color", QuestPalette.UI_TEXT_BLOCKED)
	_message.add_theme_font_size_override("font_size", 13)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)
	var inventory := ManagerLocator.get_party_inventory()
	if inventory:
		inventory.stash_changed.connect(refresh)
		inventory.equipment_changed.connect(func(_h: String, _s: ItemData.Slot, _i: ItemData) -> void: refresh())


func bind(p_hero_id: String) -> void:
	if p_hero_id != hero_id:
		_message.text = ""
	hero_id = p_hero_id
	refresh()


func refresh() -> void:
	var inventory := ManagerLocator.get_party_inventory()
	if inventory == null or hero_id == "" or not is_visible_in_tree():
		return
	_clear(_slots_row)
	for slot in SLOT_ORDER:
		var equipped := inventory.get_equipped(hero_id, slot)
		for index in int(inventory.SLOT_CAPACITY[slot]):
			_slots_row.add_child(_make_slot(slot, index, equipped[index] if index < equipped.size() else null))
	_bonus_label.text = _bonus_text(inventory)

	_clear(_stash_grid)
	_stash_title.text = "Mochila del grupo (%d / %d)" % [inventory.stash_size(), inventory.STASH_CAPACITY]
	for stack in inventory.stash:
		_stash_grid.add_child(_make_stash_cell(stack))


# ---------------- slots ----------------

func _make_slot(slot: ItemData.Slot, index: int, item: ItemData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var cell := _make_cell(item, ItemData.SLOT_LABELS[slot])
	cell.tooltip_text = ("%s\nClic: desequipar" % _item_tooltip(item, null)) if item else "%s: vacío" % ItemData.SLOT_LABELS[slot]
	if item:
		cell.pressed.connect(_on_slot_pressed.bind(slot, index))
	else:
		cell.disabled = true
	box.add_child(cell)
	if slot == ItemData.Slot.CONSUMABLE:
		var use := Button.new()
		use.text = "Usar"
		use.disabled = item == null
		use.custom_minimum_size = Vector2(CELL.x, 0)
		use.pressed.connect(_on_use_pressed.bind(index))
		box.add_child(use)
	return box


func _on_slot_pressed(slot: ItemData.Slot, index: int) -> void:
	var inventory := ManagerLocator.get_party_inventory()
	var reason := inventory.can_unequip(hero_id, slot, index)
	_message.text = reason
	if reason == "":
		inventory.unequip(hero_id, slot, index)


func _on_use_pressed(index: int) -> void:
	var hero := _hero()
	if hero == null or hero.inventory == null:
		return
	_message.text = hero.inventory.get_block_reason(index)
	hero.inventory.use(index)


func _hero() -> Player:
	for hero in ManagerLocator.get_heroes():
		if hero.stats.hero_id == hero_id:
			return hero
	return null


# ---------------- stash ----------------

func _make_stash_cell(stack: ItemStack) -> Control:
	var item := stack.item
	var cell := _make_cell(item, "")
	if stack.count > 1:
		cell.text = "x%d" % stack.count
		cell.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cell.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var reason := ManagerLocator.get_party_inventory().can_equip(hero_id, item)
	cell.tooltip_text = _item_tooltip(item, null if item.is_consumable() else _equipped_in(item.slot))
	if reason != "":
		cell.tooltip_text += "\n" + reason
		cell.modulate = Color(1, 1, 1, 0.55)
	cell.pressed.connect(_on_stash_pressed.bind(item))
	return cell


func _on_stash_pressed(item: ItemData) -> void:
	var inventory := ManagerLocator.get_party_inventory()
	var reason := inventory.can_equip(hero_id, item)
	_message.text = reason
	if reason == "":
		inventory.equip(hero_id, item)


func _equipped_in(slot: ItemData.Slot) -> ItemData:
	var list := ManagerLocator.get_party_inventory().get_equipped(hero_id, slot)
	return list[0] if not list.is_empty() else null


## What this hero's gear adds in total ("Equipo: +3 Daño"); level and base live in the sheet.
func _bonus_text(inventory) -> String:
	var bonus: Dictionary = inventory.get_equipment_bonus(hero_id)
	var mods := {}
	for key: String in ItemData.MODIFIER_KEYS:
		if not is_zero_approx(float(bonus[key])):
			mods[key] = bonus[key]
	var text := ItemData.format_modifiers(mods)
	return "Equipo suma: %s" % text if text != "" else "Sin bonos de equipo"


# ---------------- shared ----------------

## Square button framed in the item's rarity color (placeholder letter if it has no icon).
func _make_cell(item: ItemData, empty_label: String) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = CELL
	cell.expand_icon = true
	cell.focus_mode = Control.FOCUS_NONE
	var border := item.color() if item else QuestPalette.UI_PANEL_BORDER
	for state in ["normal", "hover", "pressed", "disabled"]:
		cell.add_theme_stylebox_override(state, UiStyles.build_panel_style(QuestPalette.DUNGEON_STONE, border, 3 if state == "hover" else 2, 4, 3))
	if item == null:
		cell.text = empty_label.left(3)
		cell.add_theme_color_override("font_disabled_color", QuestPalette.UI_TEXT_MUTED)
	elif item.icon:
		cell.icon = item.icon
	else:
		cell.text = item.display_name.left(1)
	return cell


## Name (rarity), slot, effect, restriction, description and, for gear, the change vs `current`.
func _item_tooltip(item: ItemData, current: ItemData) -> String:
	var lines: Array[String] = ["%s (%s) · %s" % [item.display_name, ItemData.RARITY_LABELS[item.rarity], ItemData.SLOT_LABELS[item.slot]]]
	if item.describe_stats() != "":
		lines.append(item.describe_stats())
	if not item.is_consumable() and current != null and current != item:
		var change := item.describe_change_from(current)
		lines.append("Frente a %s: %s" % [current.display_name, change if change != "" else "sin cambios"])
	if item.describe_restriction() != "":
		lines.append(item.describe_restriction())
	if item.description != "":
		lines.append(item.description)
	return "\n".join(lines)


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
