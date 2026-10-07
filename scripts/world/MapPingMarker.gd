class_name MapPingMarker
extends Node2D

## coop-12 phase 7: a player's map ping in the world: rings expanding from a
## room's center in that player's color for LIFE_SEC (real time, so it also
## shows during the tactical pause). Unshaded: readable over dark rooms.

const LIFE_SEC := 3.0
const RADIUS := 56.0
const UNSHADED: CanvasItemMaterial = preload("res://resources/maps/unshaded_material.tres")

var color := Color.WHITE
var _born_ms := 0


func setup(p_color: Color) -> MapPingMarker:
	color = p_color
	return self


func _ready() -> void:
	z_index = 55
	material = UNSHADED
	_born_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if get_age() >= LIFE_SEC:
		queue_free()
		return
	queue_redraw()


func get_age() -> float:
	return (Time.get_ticks_msec() - _born_ms) / 1000.0


func _draw() -> void:
	var t := fmod(get_age(), 1.0)
	for k in 2:
		var f := fmod(t + k * 0.5, 1.0)
		var c := color
		c.a = 1.0 - f
		draw_arc(Vector2.ZERO, RADIUS * (0.3 + f), 0.0, TAU, 32, c, 3.0)
	draw_circle(Vector2.ZERO, 6.0, color)
