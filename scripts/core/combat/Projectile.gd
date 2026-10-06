class_name Projectile
extends Node2D

## Projectile (heroes-9): a ranged hero's auto-attack in flight. Code-built
## (no scene, like Chest). Homes on the target hurtbox at `speed` px/s of game
## time (frozen in the tactical pause) and lands the hit on arrival:
## receive_hit + the shooter hitbox's hit_landed (damage numbers, VFX). A
## target freed mid-flight (killed by someone else) just fizzles.

const RADIUS := 4.0
const TRAIL := 14.0
## Arrival distance (px).
const HIT_DIST := 8.0
## Safety: never fly longer than this (s).
const MAX_LIFE := 3.0

var target: HurtboxComponent
var source: HitboxComponent
var damage: int = 0
var speed: float = 900.0
var color: Color = Color.WHITE
var _life := 0.0
var _dir := Vector2.RIGHT


## Fired from `from` (world) at `p_target`; add to the tree first.
static func fire(parent: Node, from: Vector2, p_target: HurtboxComponent, p_source: HitboxComponent, p_damage: int, p_speed: float, p_color: Color) -> Projectile:
	var projectile := Projectile.new()
	projectile.name = "Projectile"
	projectile.target = p_target
	projectile.source = p_source
	projectile.damage = p_damage
	projectile.speed = p_speed
	projectile.color = p_color
	projectile.z_index = 40
	parent.add_child(projectile)
	projectile.global_position = from
	return projectile


func _process(delta: float) -> void:
	_life += delta
	if not is_instance_valid(target) or _life > MAX_LIFE:
		queue_free()
		return
	var to := target.global_position - global_position
	if to.length() <= maxf(HIT_DIST, speed * delta):
		_land()
		return
	_dir = to.normalized()
	global_position += _dir * speed * delta
	queue_redraw()


func _land() -> void:
	target.receive_hit(damage)
	if is_instance_valid(source):
		source.hit_landed.emit(target, damage)
	queue_free()


func _draw() -> void:
	draw_line(-_dir * TRAIL, Vector2.ZERO, Color(color, 0.45), 3.0)
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color.WHITE)
