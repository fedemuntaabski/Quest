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
## Knockback (heroes-9): visual-only push away from the hit, then back.
const KNOCKBACK_PX := 6.0
const KNOCKBACK_TIME := 0.12
## Attack lunge (juego-21): visual-only step toward the target, then back.
const LUNGE_PX := 5.0
const LUNGE_TIME := 0.14
## Downed topple / revive stand-up and the enemy corpse that falls and fades.
const TOPPLE_TIME := 0.25
const CORPSE_TIME := 0.45
const DOWNED_TINT := Color(0.45, 0.45, 0.5, 0.85)
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
var _knock: Tween
var _topple: Tween
## Rest position while a knockback tween runs (the owner's actions never touch
## the visual's position, only the owner's).
var _rest_position := Vector2.INF
var _material: ShaderMaterial


func _ready() -> void:
	_last_position = global_position
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	_material.set_shader_parameter("flash", 0.0)
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
	var base := _rest_position if _rest_position != Vector2.INF else position
	return base + Vector2(0.0, -body_size().y * 0.5)


func fit_radius() -> float:
	var size := body_size()
	return maxf(size.x, size.y) * BODY_RADIUS_FACTOR


## White blink (+ the "hit" animation when the frames have one).
func play_hit() -> void:
	_hit_left = HIT_TIME
	if _flash and _flash.is_valid():
		_flash.kill()
	if not Accessibility.reduce_flashes:
		_material.set_shader_parameter("flash", 1.0)
		_flash = create_tween()
		_flash.tween_property(_material, "shader_parameter/flash", 0.0, FLASH_TIME)
	_refresh(false)


## Short push of the sprite along `dir` (unit, away from the attacker) and back.
## Only the visual moves: the owner's position/zone and its move tweens are untouched.
func knockback(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	if _knock and _knock.is_valid():
		_knock.kill()
	_end_slide()
	if _rest_position == Vector2.INF:
		_rest_position = position
	position = _rest_position
	_knock = create_tween()
	_knock.tween_property(self, "position", _rest_position + dir.normalized() * KNOCKBACK_PX, KNOCKBACK_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_knock.tween_property(self, "position", _rest_position, KNOCKBACK_TIME * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_knock.finished.connect(func() -> void: _rest_position = Vector2.INF)


## juego-22: slides the rest spot to `p` (Player turns its party offset in vertical
## corridors) instead of jumping there; a running lunge/knockback ends first.
const REST_SLIDE_TIME := 0.15
var _slide: Tween
var _slide_to := Vector2.INF


func set_rest(p: Vector2) -> void:
	if _knock and _knock.is_valid():
		_knock.kill()
		position = _rest_position if _rest_position != Vector2.INF else position
	_rest_position = Vector2.INF
	_end_slide()
	if not is_inside_tree():
		position = p
		return
	_slide_to = p
	_slide = create_tween()
	_slide.tween_property(self, "position", p, REST_SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A push/lunge starting mid-slide starts from where the slide was going.
func _end_slide() -> void:
	if _slide and _slide.is_valid():
		_slide.kill()
		position = _slide_to
	_slide_to = Vector2.INF


## Attack lunge toward `dir` (unit): same rest-position bookkeeping as knockback,
## a hit taken meanwhile simply replaces it.
func lunge(dir: Vector2) -> void:
	if dir == Vector2.ZERO or is_knocked_back():
		return
	if absf(dir.x) > 0.01:
		flip_h = dir.x < 0.0
	_end_slide()
	if _rest_position == Vector2.INF:
		_rest_position = position
	position = _rest_position
	_knock = create_tween()
	_knock.tween_property(self, "position", _rest_position + dir.normalized() * LUNGE_PX, LUNGE_TIME * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_knock.tween_property(self, "position", _rest_position, LUNGE_TIME * 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_knock.finished.connect(func() -> void: _rest_position = Vector2.INF)


## Downed hero: tips over onto its side and greys out; `false` stands it back up.
func set_downed(downed: bool) -> void:
	if _topple and _topple.is_valid():
		_topple.kill()
	_topple = create_tween().set_parallel()
	_topple.tween_property(self, "rotation", PI * 0.5 if downed else 0.0, TOPPLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN if downed else Tween.EASE_OUT)
	_topple.tween_property(self, "self_modulate", DOWNED_TINT if downed else Color.WHITE, TOPPLE_TIME)


## Enemy death: a copy of the current frame topples and fades under `parent` (the
## enemies root: freed with the floor; the owner is freed right away). Cosmetic,
## null when there is nothing to copy.
func spawn_corpse(parent: Node) -> Sprite2D:
	if parent == null or sprite_frames == null or not visible:
		return null
	var corpse := Sprite2D.new()
	corpse.texture = sprite_frames.get_frame_texture(animation, frame)
	corpse.centered = centered
	corpse.offset = _base_offset
	corpse.flip_h = flip_h
	corpse.scale = scale
	corpse.modulate = modulate
	corpse.z_index = 1
	parent.add_child(corpse)
	corpse.global_position = global_position
	var side := -1.0 if flip_h else 1.0
	var tween := corpse.create_tween().set_parallel()
	tween.tween_property(corpse, "rotation", side * PI * 0.5, CORPSE_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(corpse, "modulate:a", 0.0, CORPSE_TIME).set_delay(CORPSE_TIME * 0.3)
	tween.chain().tween_callback(corpse.queue_free)
	return corpse


func is_knocked_back() -> bool:
	return _knock != null and _knock.is_valid() and _knock.is_running()


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
