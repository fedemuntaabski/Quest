class_name CharacterVisual
extends AnimatedSprite2D

## CharacterVisual: shared sprite for heroes and enemies. Picks idle / run /
## hit from what the node does (its own displacement per frame — the actions
## that move the owner stay untouched), flips towards the movement direction,
## flashes white on damage, and bounces static single-frame sprites (Tiny
## Creatures, no "run" animation) procedurally. Art faces right by default.
## Feet sit on the parent's origin; body_size() is the drawn size in world px.

const FLASH_SHADER := preload("res://resources/shaders/white_flash.gdshader")
## Displacement per frame (px) that counts as moving, and how long "running"
## outlives the last step (keeps short glides from flickering).
const MOVE_EPSILON := 0.2
## A step this big in one frame is a teleport (spawn, set_zone), not running.
const TELEPORT_PX := 80.0
const RUN_HOLD := 0.12
const HIT_TIME := 0.2
const FLASH_TIME := 0.15
const BOUNCE_PX := 2.0
const BOUNCE_IDLE_TIME := 0.7
const BOUNCE_RUN_TIME := 0.3
## Collision circle = this fraction of the drawn body's longer side.
const BODY_RADIUS_FACTOR := 0.4

enum State { IDLE, RUN, HIT }

var state: State = State.IDLE

var _last_position: Vector2
var _run_left: float = 0.0
var _hit_left: float = 0.0
var _procedural: bool = false
var _base_offset: Vector2 = Vector2.ZERO
var _bounce_time: float = 0.0
var _bounce: Tween
var _flash: Tween
var _material: ShaderMaterial


func _ready() -> void:
	_last_position = global_position
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	material = _material


## Applies `frames` at ArtConfig.ART_SCALE x `visual_scale`, feet on the origin.
func setup(frames: SpriteFrames, visual_scale: float = 1.0) -> void:
	sprite_frames = frames
	scale = Vector2.ONE * ArtConfig.ART_SCALE * visual_scale
	_base_offset = Vector2(0.0, -frame_size().y * 0.5)
	offset = _base_offset
	_procedural = frames != null and not frames.has_animation("run")
	_refresh(true)


## Size in px of the first idle frame (unscaled art).
func frame_size() -> Vector2:
	if sprite_frames == null or not sprite_frames.has_animation("idle"):
		return Vector2(16, 16)
	return sprite_frames.get_frame_texture("idle", 0).get_size()


## Drawn size in world px (frame x scale).
func body_size() -> Vector2:
	return frame_size() * scale.abs()


## Local centre of the drawn body (where collision shapes belong).
func body_center() -> Vector2:
	return position + Vector2(0.0, -body_size().y * 0.5)


func fit_radius() -> float:
	var size := body_size()
	return maxf(size.x, size.y) * BODY_RADIUS_FACTOR


## White blink (+ the "hit" animation when the frames have one).
func play_hit() -> void:
	_hit_left = HIT_TIME
	if _flash and _flash.is_valid():
		_flash.kill()
	_material.set_shader_parameter("flash", 1.0)
	_flash = create_tween()
	_flash.tween_property(_material, "shader_parameter/flash", 0.0, FLASH_TIME)
	_refresh(false)


func flash_amount() -> float:
	return _material.get_shader_parameter("flash") if _material else 0.0


func _process(delta: float) -> void:
	var step := global_position - _last_position
	_last_position = global_position
	if step.length() > MOVE_EPSILON and step.length() < TELEPORT_PX:
		_run_left = RUN_HOLD
		if absf(step.x) > MOVE_EPSILON * 0.5:
			flip_h = step.x < 0.0
	else:
		_run_left = maxf(_run_left - delta, 0.0)
	_hit_left = maxf(_hit_left - delta, 0.0)
	_refresh(false)


func _refresh(force: bool) -> void:
	if sprite_frames == null:
		return
	var wanted := State.IDLE
	if _hit_left > 0.0:
		wanted = State.HIT
	elif _run_left > 0.0:
		wanted = State.RUN
	if wanted == state and not force:
		return
	state = wanted
	var anim := &"idle"
	if state == State.HIT and sprite_frames.has_animation("hit"):
		anim = &"hit"
	elif state == State.RUN and sprite_frames.has_animation("run"):
		anim = &"run"
	if animation != anim or not is_playing():
		play(anim)
	if _procedural:
		_start_bounce(BOUNCE_RUN_TIME if state == State.RUN else BOUNCE_IDLE_TIME)


func _start_bounce(period: float) -> void:
	if is_equal_approx(period, _bounce_time) and _bounce and _bounce.is_valid():
		return
	_bounce_time = period
	if _bounce and _bounce.is_valid():
		_bounce.kill()
	offset = _base_offset
	_bounce = create_tween().set_loops()
	_bounce.tween_property(self, "offset:y", _base_offset.y - BOUNCE_PX, period * 0.5).set_trans(Tween.TRANS_SINE)
	_bounce.tween_property(self, "offset:y", _base_offset.y, period * 0.5).set_trans(Tween.TRANS_SINE)
