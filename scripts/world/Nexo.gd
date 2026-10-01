extends Area2D
class_name Nexo

## Nexo: clickable pickup in the start room (just above its center). Click
## plumbing mirrors Door.gd. NexoController owns the pickup rule (exit room
## discovered + hero in the start room), the confirmation dialog and the
## extraction kick-off.

signal nexo_clicked(nexo: Nexo)
signal hp_changed(current: int, maximum: int)
## true on a hit, false UNDER_ATTACK_SEC after the last one (HUD alert).
signal under_attack_changed(active: bool)
## HP reached 0: Main2d applies the usual defeat.
signal destroyed

const FLASH_SHADER := preload("res://resources/shaders/white_flash.gdshader")
const FLASH_SEC := 0.15
const UNDER_ATTACK_SEC := 1.5
## Crack i shows once HP <= CRACK_THRESHOLDS[i] of max (local px polylines).
const CRACK_THRESHOLDS := [0.75, 0.5, 0.25]
const CRACK_LINES := [
	[Vector2(-2, -14), Vector2(2, -8), Vector2(-3, -3)],
	[Vector2(6, -6), Vector2(1, 0), Vector2(5, 7)],
	[Vector2(-8, 2), Vector2(-3, 6), Vector2(-6, 13)],
]

## Raiders (Enemy.Role RAIDER) wear this down; 0 = the defeat condition.
@export var max_hp: int = 100

var current_hp: int = 100
var under_attack: bool = false
var cracks: Array[Line2D] = []
var _picked_up: bool = false
var _flash_material: ShaderMaterial
var _flash_tween: Tween
var _attack_timer: Timer


func _ready() -> void:
	add_to_group("nexo")
	current_hp = max_hp
	z_index = 2
	input_event.connect(_on_input_event)
	_build_feedback()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _picked_up:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if get_viewport().is_input_handled():
		return
	nexo_clicked.emit(self)
	get_viewport().set_input_as_handled()


func take_damage(amount: int) -> void:
	if current_hp <= 0 or amount <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	hp_changed.emit(current_hp, max_hp)
	_play_hit(amount)
	_update_cracks()
	_set_under_attack(true)
	_attack_timer.start(UNDER_ATTACK_SEC)
	if current_hp <= 0:
		QuestLogger.info(QuestLogger.Category.NEXO, "Nexo destroyed.")
		destroyed.emit()


## 0 = intact .. CRACK_THRESHOLDS.size() = most cracked.
func crack_stage() -> int:
	var stage := 0
	for threshold in CRACK_THRESHOLDS:
		if current_hp <= threshold * max_hp:
			stage += 1
	return stage


func is_alive() -> bool:
	return current_hp > 0


## The hero carrying it, or null while it sits in the start room.
func get_carrier() -> Player:
	for hero in ManagerLocator.get_heroes():
		if hero.is_carrying_nexo:
			return hero
	return null


## Where raiders must go: the carrier once picked up, else the start-room spot.
func get_target_position() -> Vector2:
	var carrier := get_carrier()
	return carrier.global_position if carrier else global_position


func get_target_zone(room_manager: RoomManager) -> String:
	var carrier := get_carrier()
	return carrier.current_zone_id if carrier else room_manager.get_start_zone_id()


func pick_up() -> void:
	_picked_up = true
	visible = false
	input_pickable = false


func _build_feedback() -> void:
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = FLASH_SHADER
	$Pickup/Sprite2D.material = _flash_material
	for points in CRACK_LINES:
		var line := Line2D.new()
		line.points = PackedVector2Array(points)
		line.width = 1.5
		line.default_color = Color(0.1, 0.02, 0.02, 0.9)
		line.z_index = 1
		line.visible = false
		add_child(line)
		cracks.append(line)
	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.timeout.connect(_set_under_attack.bind(false))
	add_child(_attack_timer)


func _update_cracks() -> void:
	var stage := crack_stage()
	for i in cracks.size():
		cracks[i].visible = i < stage


func _set_under_attack(active: bool) -> void:
	if under_attack != active:
		under_attack = active
		under_attack_changed.emit(active)


## White flash on the sprite (hidden once carried) + the damage number where raiders strike.
func _play_hit(amount: int) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_material.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween().set_ignore_time_scale()
	_flash_tween.tween_property(_flash_material, "shader_parameter/flash", 0.0, FLASH_SEC)
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(get_target_position(), "-%d" % amount, QuestPalette.BLOOD_LIGHT)
