class_name AltarShrine
extends Node2D

## AltarShrine (progresion-10): risk/reward event of an Altar room. Left click with
## a living hero inside opens a dialog: that hero (the primary selected one if it is
## in the room) gives `hp_cost` HP (RoomTypeRule.altar_hp_pct of its max HP) for an
## item of at least `min_rarity` from the floor's chest table. One use. Refused when
## the price would down the hero or the stash is full. Code-built like PrisonerCage.

signal used(hero_id: String, item: ItemData)

const SIZE := Vector2(48, 40)
const STONE := Color(0.42, 0.4, 0.44)
const GLOW := Color(0.85, 0.25, 0.3)

var zone_id: String = ""
var hp_pct: float = 0.3
var min_rarity: int = ItemData.Rarity.RARE
var floor_index: int = 1
var map_seed: int = 0
var is_used: bool = false
var dialog: ConfirmationDialog


func setup(p_zone_id: String, p_hp_pct: float, p_min_rarity: int, p_floor_index: int, p_map_seed: int) -> void:
	zone_id = p_zone_id
	hp_pct = p_hp_pct
	min_rarity = p_min_rarity
	floor_index = p_floor_index
	map_seed = p_map_seed


func _ready() -> void:
	z_index = 2
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	shape.position = Vector2(0, -SIZE.y * 0.5)
	area.add_child(shape)
	area.input_event.connect(_on_input_event)
	add_child(area)
	dialog = ConfirmationDialog.new()
	dialog.name = "AltarDialog"
	dialog.title = "Altar de sangre"
	dialog.ok_button_text = "Sacrificar"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(func() -> void:
		var hero := offering_hero()
		if hero:
			ManagerLocator.get_net_commands().request("altar", {"zone": zone_id, "hero": hero.stats.hero_id}))
	add_child(dialog)


func _draw() -> void:
	var base := Rect2(Vector2(-SIZE.x * 0.5, -SIZE.y * 0.45), Vector2(SIZE.x, SIZE.y * 0.45))
	draw_rect(base, STONE)
	draw_rect(Rect2(base.position + Vector2(6, -10), Vector2(SIZE.x - 12, 10)), STONE.lightened(0.15))
	draw_rect(base, STONE.darkened(0.4), false, 2.0)
	if not is_used:
		draw_circle(Vector2(0, -SIZE.y * 0.62), 6.0, GLOW)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_used or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	get_viewport().set_input_as_handled()
	open_dialog()


## The hero who would pay: the primary selected hero if alive in the room, else
## the first living hero inside; null if nobody is here.
## coop-12: `preferred_id` (the commanding hero) wins when it stands here.
func offering_hero(preferred_id: String = "") -> Player:
	var selection := ManagerLocator.get_selection_manager()
	var primary_id: String = preferred_id if preferred_id != "" else (selection.get_primary_id() if selection else "")
	var fallback: Player = null
	for hero in ManagerLocator.get_heroes():
		if not hero.stats.is_alive() or hero.current_zone_id != zone_id:
			continue
		if hero.stats.hero_id == primary_id:
			return hero
		if fallback == null:
			fallback = hero
	return fallback


func hp_cost(hero: Player) -> int:
	return maxi(1, roundi(hero.stats.max_hp * hp_pct))


## Why it can't be used now ("" = it can).
func get_block_reason(hero_id: String = "") -> String:
	if is_used:
		return "El altar ya bebió"
	var hero := offering_hero(hero_id)
	if hero == null:
		return "Un héroe tiene que estar en la sala"
	if hero.stats.current_hp <= hp_cost(hero):
		return "%s necesita más de %d de vida" % [hero.stats.character_name, hp_cost(hero)]
	var inventory := ManagerLocator.get_party_inventory()
	if inventory and inventory.stash.size() >= inventory.STASH_CAPACITY:
		return "Mochila llena"
	return ""


func open_dialog() -> void:
	var reason := get_block_reason()
	if reason != "":
		_say(reason, QuestPalette.PARCHMENT)
		return
	var hero := offering_hero()
	dialog.dialog_text = "%s puede ofrecer %d de vida a cambio de un objeto %s o mejor.\nEl altar solo acepta una ofrenda." % [hero.stats.character_name, hp_cost(hero), ItemData.RARITY_LABELS[min_rarity].to_lower()]
	dialog.popup_centered()


## Pays the HP and grants the item (seeded per floor + room). Null when blocked.
func sacrifice(hero_id: String = "") -> ItemData:
	if get_block_reason(hero_id) != "":
		return null
	var hero := offering_hero(hero_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map_seed, zone_id, "altar"])
	var item := LootSpawner.roll_item(rng, floor_index, min_rarity)
	var inventory := ManagerLocator.get_party_inventory()
	if item == null or inventory == null or not inventory.add_item(item):
		return null
	hero.stats.take_damage(hp_cost(hero))
	is_used = true
	queue_redraw()
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"hit_sparks", hero.global_position, GLOW)
	_say("%s (%s)" % [item.display_name, ItemData.RARITY_LABELS[item.rarity]], item.color())
	used.emit(hero.stats.hero_id, item)
	return item


func _say(text: String, color: Color) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager()
	if text_mgr:
		text_mgr.spawn_text(global_position + Vector2(0, -SIZE.y - 12), text, color)
