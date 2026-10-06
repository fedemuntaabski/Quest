class_name PrisonerCage
extends Node2D

## PrisonerCage (heroes-9): a hero locked in a Prisoner room, one the party
## didn't pick. Code-built like Chest. Left click with a living hero inside the
## room opens a dialog with one button per price (RoomTypeRule.recruit_costs:
## Industria or Comida); paying frees the hero, who joins the party right away
## (Main2d.recruit_hero via `recruit`) and on the next floors. Drawn: the
## hero's idle frame in grey behind code-drawn bars.

signal freed(hero_id: String)

const SIZE := Vector2(44, 52)
const BAR_COLOR := Color(0.72, 0.7, 0.66, 1.0)
## GameSession.MAX_PARTY (preloaded: autoload names aren't identifiers in --script tests).
const MAX_PARTY: int = preload("res://scripts/autoload/GameSession.gd").MAX_PARTY
const RESOURCE_NAMES := {"industry": "Industria", "food": "Comida", "science": "Ciencia", "dust": "Polvo"}

var hero_id: String = ""
var zone_id: String = ""
## resource key -> amount (already scaled to the floor).
var costs: Dictionary = {}
## func(hero_id: String, zone_id: String) -> Player (Main2d.recruit_hero).
var recruit: Callable
var is_freed: bool = false
var dialog: ConfirmationDialog

var _sprite: Sprite2D
var _bars: Node2D


func setup(p_hero_id: String, p_zone_id: String, p_costs: Dictionary, p_recruit: Callable) -> void:
	hero_id = p_hero_id
	zone_id = p_zone_id
	costs = p_costs
	recruit = p_recruit


func _ready() -> void:
	z_index = 2
	var data := CharacterDatabase.get_by_id(hero_id)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * ArtConfig.ART_SCALE
	_sprite.modulate = Color(0.55, 0.55, 0.6)
	if data and data.sprite_frames and data.sprite_frames.has_animation("idle"):
		_sprite.texture = data.sprite_frames.get_frame_texture("idle", 0)
		_sprite.offset = Vector2(0, -_sprite.texture.get_size().y * 0.5)
	add_child(_sprite)
	# Bars in front of the prisoner (a parent's _draw would sit behind the sprite).
	var bars := Node2D.new()
	bars.name = "Bars"
	bars.draw.connect(_draw_bars.bind(bars))
	add_child(bars)
	_bars = bars

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
	_build_dialog(data)


func _draw_bars(canvas: Node2D) -> void:
	if is_freed:
		return
	var rect := Rect2(Vector2(-SIZE.x * 0.5, -SIZE.y), SIZE)
	for i in 5:
		var x := rect.position.x + rect.size.x * float(i) / 4.0
		canvas.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), BAR_COLOR, 3.0)
	canvas.draw_rect(rect, BAR_COLOR, false, 3.0)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_freed or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	get_viewport().set_input_as_handled()
	open_dialog()


## Why it can't be opened now ("" = it can): nobody alive inside, party full.
func get_block_reason() -> String:
	if is_freed:
		return "Ya fue liberado"
	var heroes := ManagerLocator.get_heroes()
	if heroes.size() >= MAX_PARTY:
		return "El grupo ya tiene %d héroes" % MAX_PARTY
	for hero in heroes:
		if hero.stats.is_alive() and hero.current_zone_id == zone_id:
			return ""
	return "Un héroe tiene que estar en la sala"


func open_dialog() -> void:
	var reason := get_block_reason()
	if reason != "":
		_say(reason, QuestPalette.PARCHMENT)
		return
	_refresh_buttons()
	dialog.popup_centered()


## Pays `resource_key`'s price and frees the hero. false = not on offer, blocked or short.
func free_with(resource_key: String) -> bool:
	if not costs.has(resource_key) or get_block_reason() != "":
		return false
	var resources := ManagerLocator.get_resource_manager()
	if resources == null or not resources.spend_resource(resource_key, int(costs[resource_key])):
		_say("Falta %s" % RESOURCE_NAMES.get(resource_key, resource_key), QuestPalette.UI_TEXT_BLOCKED)
		return false
	var hero: Player = recruit.call(hero_id, zone_id) if recruit.is_valid() else null
	if hero == null:
		resources.add_resource(resource_key, int(costs[resource_key]))  # refund: nothing was freed
		return false
	is_freed = true
	_sprite.visible = false
	_bars.queue_redraw()
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"level_up", hero.global_position, hero.vfx_color())
	_say("%s se une al grupo" % hero.stats.character_name, QuestPalette.GOLD_LIGHT)
	freed.emit(hero_id)
	return true


func _build_dialog(data: CharacterData) -> void:
	dialog = ConfirmationDialog.new()
	dialog.name = "PrisonerDialog"
	dialog.title = "Prisionero"
	var name := data.display_name if data else hero_id
	dialog.dialog_text = "%s está encerrado. Liberalo y se une al grupo." % name
	dialog.get_ok_button().visible = false
	dialog.cancel_button_text = "Cancelar"
	for key: String in costs:
		var button := dialog.add_button("Liberar (%d %s)" % [costs[key], RESOURCE_NAMES.get(key, key)], false, key)
		button.set_meta("resource", key)
	dialog.custom_action.connect(_on_custom_action)
	add_child(dialog)


func _on_custom_action(action: StringName) -> void:
	dialog.hide()
	free_with(String(action))


## Price buttons are disabled when the party can't afford them.
func _refresh_buttons() -> void:
	var resources := ManagerLocator.get_resource_manager()
	for button in dialog.find_children("*", "Button", true, false):
		if not button.has_meta("resource"):
			continue
		var key: String = button.get_meta("resource")
		button.disabled = resources == null or resources.get_resource(key) < int(costs[key])


func _say(text: String, color: Color) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager()
	if text_mgr:
		text_mgr.spawn_text(global_position + Vector2(0, -SIZE.y - 12), text, color)
