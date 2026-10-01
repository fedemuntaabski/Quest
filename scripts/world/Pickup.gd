class_name Pickup
extends Node2D

## Pickup: reusable floating item sprite (crystal, dust, weapon, chest). Pure
## visual — clicking/collecting belongs to the owner (e.g. Nexo, an Area2D
## that instances this). Bobs with a looping Tween.

enum Kind { CRYSTAL, DUST, WEAPON, CHEST }

## 0x72 items (assets/art/items); the chest is a Kenney prop (props palette).
const TEXTURES := {
	Kind.CRYSTAL: "res://assets/art/items/flask_big_blue.png",
	Kind.DUST: "res://assets/art/items/coin_anim_f0.png",
	Kind.WEAPON: "res://assets/art/items/weapon_regular_sword.png",
}
const CHEST_SHEET := "res://assets/art/_source/kenney_tinyDungeon/Tilemap/tilemap_packed.png"
const CHEST_REGION := Rect2(80, 112, 16, 16)  # tile (5, 7)

@export var kind: Kind = Kind.CRYSTAL:
	set(value):
		kind = value
		if is_node_ready():
			_apply_kind()
## Objeto mostrado: reemplaza el sprite del `kind`; en un cofre flota encima como
## contenido. Solo visual (el juego aún no tiene sistema de equipo).
@export var item: ItemData:
	set(value):
		item = value
		if is_node_ready():
			_apply_kind()
@export var float_amplitude: float = 4.0
@export var float_time: float = 0.9

@onready var sprite: Sprite2D = $Sprite2D

const ITEM_ICON_OFFSET := Vector2(0, -20)

var _bob: Tween
var _item_icon: Sprite2D


func _ready() -> void:
	sprite.scale = Vector2.ONE * ArtConfig.ART_SCALE
	_apply_kind()
	_bob = create_tween().set_loops()
	_bob.tween_property(sprite, "position:y", -float_amplitude, float_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(sprite, "position:y", float_amplitude, float_time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_kind() -> void:
	if _item_icon:
		_item_icon.queue_free()
		_item_icon = null
	if item and kind != Kind.CHEST:
		sprite.texture = item.icon
		return
	if item:
		_item_icon = Sprite2D.new()
		_item_icon.texture = item.icon
		_item_icon.position = ITEM_ICON_OFFSET
		sprite.add_child(_item_icon)
	if kind == Kind.CHEST:
		var atlas := AtlasTexture.new()
		atlas.atlas = load(CHEST_SHEET)
		atlas.region = CHEST_REGION
		sprite.texture = atlas
	else:
		sprite.texture = load(TEXTURES[kind])
