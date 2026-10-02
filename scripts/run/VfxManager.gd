extends Node
class_name VfxManager

## VfxManager: pooled, capped combat/ability effects (scenes in scenes/vfx,
## tunables in resources/vfx/vfx_config.tres). Lazy singleton under the scene
## root (ManagerLocator.get_vfx_manager()), same pattern as FloatingTextManager.
## Purely cosmetic: callers null-guard it and never depend on the result.

const SCENE_PATH := "res://scenes/vfx/%s.tscn"
const MAX_POOLED_PER_SCENE := 8
const Z_INDEX := 90  # under FloatingText (100)

var config: VfxConfig = preload("res://resources/vfx/vfx_config.tres")

var _scenes: Dictionary = {}
var _free: Dictionary = {}
var _active := 0


func _ready() -> void:
	add_to_group("vfx_manager")


func get_active_count() -> int:
	return _active


## Plays effect `id` at world `pos`; null when unknown or the cap is reached.
func play(id: StringName, pos: Vector2, color: Color = Color.WHITE, angle: float = 0.0, to: Vector2 = Vector2.INF) -> VfxEffect:
	var def := config.get_effect(id)
	if def.is_empty() or _active >= config.max_active:
		return null
	var effect := _acquire(String(def["scene"]))
	if effect == null:
		return null
	effect.global_position = pos
	_active += 1
	effect.play(def, color, angle, to)
	return effect


## Auto-attack hit: slash toward the target + sparks in `color`; shakes only if strong.
func hit(from: Vector2, target: Vector2, color: Color, amount: int, target_max_hp: int) -> void:
	play(&"hit_slash", target, color, from.angle_to_point(target))
	play(&"hit_sparks", target, color)
	shake_if_strong(amount, target_max_hp)


## Damage taken (hero, Nexo): red flash.
func hurt(pos: Vector2, amount: int, max_hp: int) -> void:
	play(&"damage_flash", pos, config.damage_color)
	shake_if_strong(amount, max_hp)


func shake_if_strong(amount: int, max_hp: int) -> void:
	if amount >= config.shake_min_damage and amount >= config.shake_threshold_pct * max_hp:
		shake()


func shake(factor: float = 1.0) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d() as GameCamera if viewport else null
	if camera:
		camera.shake(config.shake_strength * factor, config.shake_duration)


## Drops every pooled/playing effect (new floor).
func clear() -> void:
	for child in get_children():
		child.queue_free()
	_free.clear()
	_active = 0


func _acquire(scene_name: String) -> VfxEffect:
	var pool: Array = _free.get(scene_name, [])
	while not pool.is_empty():
		var reused := pool.pop_back() as VfxEffect
		if is_instance_valid(reused):
			return reused
	if not _scenes.has(scene_name):
		_scenes[scene_name] = load(SCENE_PATH % scene_name)
	var scene := _scenes[scene_name] as PackedScene
	if scene == null:
		return null
	var effect := scene.instantiate() as VfxEffect
	effect.scene_name = scene_name
	effect.z_index = Z_INDEX
	effect.finished.connect(_release)
	add_child(effect)
	return effect


func _release(effect: VfxEffect) -> void:
	_active = maxi(_active - 1, 0)
	var pool: Array = _free.get(effect.scene_name, [])
	if pool.size() < MAX_POOLED_PER_SCENE:
		pool.append(effect)
		_free[effect.scene_name] = pool
	else:
		effect.queue_free()
