class_name Chest
extends Node2D

## Chest: a loot chest in a room (DotE style). Closed until a hero enters its
## room (LootSpawner calls try_open()): then the lid opens, the item floats over
## it framed in its rarity color with a "name (rarity)" text, and it goes to
## PartyInventory. A full stash leaves it closed with a warning; the next hero
## entering tries again. Sprites: Kenney Tiny Dungeon closed/open chest tiles
## (placeholder box drawn in code if the sheet is missing).

signal opened(item: ItemData)

enum State { CLOSED, OPEN }

const SHEET := "res://assets/art/_source/kenney_tinyDungeon/Tilemap/tilemap_packed.png"
const CLOSED_REGION := Rect2(80, 112, 16, 16)  # tile (5, 7)
const OPEN_REGION := Rect2(112, 112, 16, 16)   # tile (7, 7)
const ITEM_OFFSET := Vector2(0, -34)
const ITEM_FRAME := 22.0
const FULL_TEXT := "Mochila llena"
const WARN_COOLDOWN_MSEC := 1500

var item: ItemData
var zone_id: String = ""
var state: State = State.CLOSED

var _sprite: Sprite2D
var _item_icon: Sprite2D
var _item_frame: Node2D
var _last_warn_msec: int = -WARN_COOLDOWN_MSEC


func setup(p_item: ItemData, p_zone_id: String) -> void:
	item = p_item
	zone_id = p_zone_id


func _ready() -> void:
	z_index = 2
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2.ONE * ArtConfig.ART_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = _tile(CLOSED_REGION)
	add_child(_sprite)
	queue_redraw()


func is_closed() -> bool:
	return state == State.CLOSED


## Opens it and hands the item to the party. False (stays closed) when it is open
## already, has no item or the stash is full.
func try_open() -> bool:
	if state != State.CLOSED or item == null:
		return false
	var inventory := ManagerLocator.get_party_inventory()
	if inventory == null:
		return false
	if not inventory.can_add(item):
		_warn_full()
		return false
	inventory.add_item(item)
	state = State.OPEN
	_sprite.texture = _tile(OPEN_REGION)
	_show_item()
	_announce()
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"hit_sparks", global_position, item.color())
	QuestLogger.info(QuestLogger.Category.MAP, "Chest in '%s' opened: %s." % [zone_id, item.id])
	opened.emit(item)
	return true


func _tile(region: Rect2) -> Texture2D:
	if not ResourceLoader.exists(SHEET):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(SHEET)
	atlas.region = region
	return atlas


## Item icon above the chest, framed in the rarity color.
func _show_item() -> void:
	_item_frame = Node2D.new()
	_item_frame.position = ITEM_OFFSET
	_item_frame.draw.connect(_draw_item_frame)
	add_child(_item_frame)
	_item_icon = Sprite2D.new()
	_item_icon.texture = item.icon
	_item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_icon.scale = Vector2.ONE * ArtConfig.ART_SCALE
	_item_frame.add_child(_item_icon)
	_item_frame.queue_redraw()
	_item_frame.scale = Vector2.ZERO
	var tween := create_tween().set_ignore_time_scale()
	tween.tween_property(_item_frame, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_item_frame() -> void:
	var rect := Rect2(Vector2.ONE * -ITEM_FRAME * 0.5, Vector2.ONE * ITEM_FRAME)
	_item_frame.draw_rect(rect, Color(0.05, 0.04, 0.04, 0.85))
	_item_frame.draw_rect(rect, item.color(), false, 2.0)


func _announce() -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(global_position + Vector2(0, -64), "%s (%s)" % [item.display_name, ItemData.RARITY_LABELS[item.rarity]], item.color(), item.rarity >= ItemData.Rarity.EPIC)


func _warn_full() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_warn_msec < WARN_COOLDOWN_MSEC:
		return
	_last_warn_msec = now
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(global_position + Vector2(0, -48), FULL_TEXT, QuestPalette.UI_TEXT_BLOCKED)
	var hud := ManagerLocator.get_hud()
	if hud:
		hud.show_hint("Cofre cerrado", "La mochila del grupo está llena (%d). Libera un hueco y vuelve a entrar." % ManagerLocator.get_party_inventory().STASH_CAPACITY, QuestPalette.UI_TEXT_BLOCKED)


## Placeholder box while the sprite sheet is missing.
func _draw() -> void:
	if _sprite != null and _sprite.texture != null:
		return
	draw_rect(Rect2(-14, -10, 28, 20), Color(0.55, 0.35, 0.16))
	draw_rect(Rect2(-14, -10, 28, 20), Color(0.95, 0.78, 0.42), false, 2.0)
	if state == State.CLOSED:
		draw_rect(Rect2(-3, -2, 6, 6), Color(0.85, 0.85, 0.9))
