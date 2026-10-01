extends Node2D
class_name VfxEffect

## VfxEffect: root script of every scene in assets/vfx. An optional `Sprite`
## (AnimatedSprite2D, frames built from assets/art/vfx/index.json) and an optional
## `Particles` (CPUParticles2D, square 1-2 art px) play together for `duration`
## seconds, then `finished` fires so VfxManager can pool the node again.
## Game time (not real time): effects freeze with the tactical pause like the world.

signal finished(effect: VfxEffect)

const INDEX_PATH := "res://assets/art/vfx/index.json"
const SHEET_PATH := "res://assets/art/vfx/%s.png"
const ANIM := &"fx"

static var _index: Dictionary = {}
static var _frames: Dictionary = {}

var scene_name: String = ""
var _token := 0

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite")
@onready var particles: CPUParticles2D = get_node_or_null("Particles")


## SpriteFrames of one sheet (cached; null when the sheet is not in index.json / not imported).
static func frames_for(sheet: String) -> SpriteFrames:
	if _frames.has(sheet):
		return _frames[sheet]
	if _index.is_empty():
		_index = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH)) as Dictionary
	var info: Dictionary = _index.get(sheet, {})
	var texture := load(SHEET_PATH % sheet) as Texture2D if not info.is_empty() else null
	var frames: SpriteFrames = null
	if texture:
		frames = SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation(ANIM)
		frames.set_animation_loop(ANIM, false)
		frames.set_animation_speed(ANIM, float(info["fps"]))
		var columns := int(info["columns"])
		var size := Vector2(float(info["frame_w"]), float(info["frame_h"]))
		for i in int(info["frames"]):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(i % columns, i / columns) * size, size)
			frames.add_frame(ANIM, atlas)
	_frames[sheet] = frames
	return frames


## `def` = VfxConfig.effects entry. `to` != INF moves the effect there (projectile).
func play(def: Dictionary, color: Color, angle: float = 0.0, to: Vector2 = Vector2.INF) -> void:
	_token += 1
	var token := _token
	var duration := maxf(float(def.get("duration", 0.4)), 0.05)
	rotation = angle
	visible = true
	var sheet := String(def.get("sheet", ""))
	if sprite:
		var frames := frames_for(sheet) if sheet != "" else null
		sprite.visible = frames != null
		if frames:
			sprite.sprite_frames = frames
			sprite.scale = Vector2.ONE * float(def.get("scale", 1.0)) * ArtConfig.ART_SCALE
			sprite.modulate = color if def.get("tint", false) else Color.WHITE
			sprite.speed_scale = frames.get_frame_count(ANIM) / (frames.get_animation_speed(ANIM) * duration)
			sprite.play(ANIM)
	if particles:
		particles.color = color
		particles.restart()
		particles.emitting = true
	if to != Vector2.INF:
		create_tween().tween_property(self, "global_position", to, duration)
	await get_tree().create_timer(duration).timeout
	if token == _token:  # not re-used meanwhile
		_finish()


func _finish() -> void:
	visible = false
	if particles:
		particles.emitting = false
	if sprite:
		sprite.stop()
	finished.emit(self)
