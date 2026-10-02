class_name HeroInputController
extends Node

## Hero selection input for the floor: left click on a hero (Ctrl adds/removes),
## F1/F2 select hero 1/2, Ctrl+1..3 assign a control group, 1..3 recall it (a
## second tap within GROUP_DOUBLE_TAP_MS also centers the camera). The selection
## itself lives in SelectionManager; Main2d's `_input` forwards keys to
## `handle_key()` so the Esc/Space/Tab order of handlers is unchanged.

## Extra px around a hero's body that still count as a click on it.
const HERO_PICK_MARGIN := 10.0
## Real-time window (ms) for the second tap of a group key.
const GROUP_DOUBLE_TAP_MS := 300

var _heroes: Array[Player]
var _camera: GameCamera
var _is_gameplay_active: Callable
var _last_group_key: int = 0
var _last_group_msec: int = -10000


## `heroes` is Main2d's live array (same instance, kept in sync by the owner).
func setup(heroes: Array[Player], camera: GameCamera, is_gameplay_active: Callable) -> void:
	_heroes = heroes
	_camera = camera
	_is_gameplay_active = is_gameplay_active


## Left click on a hero selects it (Ctrl adds/removes). Consumed on purpose so the
## RoomZone under the hero doesn't also read it as a move order; a click anywhere
## else stays a move order. Not while a module is armed (its slots need the click).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _is_gameplay_active.call():
		return
	var hud := ManagerLocator.get_hud()
	if hud and hud.building_menu and hud.building_menu.is_armed():
		return
	var hero := pick_hero_at(get_viewport().get_canvas_transform().affine_inverse() * event.position)
	if hero == null:
		return
	click_hero(hero, event.ctrl_pressed)
	get_viewport().set_input_as_handled()


## Living hero whose drawn body contains `world_pos` (the closest one), or null.
func pick_hero_at(world_pos: Vector2) -> Player:
	var best: Player = null
	var best_dist := INF
	for hero in _heroes:
		if not hero.can_accept_input():
			continue
		var dist := world_pos.distance_to(hero.to_global(hero.animated_sprite.body_center()))
		if dist <= hero.animated_sprite.fit_radius() + HERO_PICK_MARGIN and dist < best_dist:
			best = hero
			best_dist = dist
	return best


func click_hero(hero: Player, additive: bool) -> void:
	var selection := ManagerLocator.get_selection_manager()
	if selection == null:
		return
	if additive:
		selection.toggle(hero.stats.hero_id)
	else:
		selection.select_only(hero.stats.hero_id)


## true = key consumed.
func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var selection := ManagerLocator.get_selection_manager()
	if selection == null:
		return false
	for i in mini(_heroes.size(), 2):
		if event.is_action_pressed("select_hero_%d" % (i + 1)):
			click_hero(_heroes[i], event.ctrl_pressed)
			return true
	for n in range(1, selection.GROUP_COUNT + 1):
		if event.is_action_pressed("group_assign_%d" % n, false, true):
			selection.assign_group(n)
			return true
		if event.is_action_pressed("group_select_%d" % n, false, true):
			if selection.select_group(n):
				var now := Time.get_ticks_msec()
				if n == _last_group_key and now - _last_group_msec <= GROUP_DOUBLE_TAP_MS:
					_center_camera_on_selection()
				_last_group_key = n
				_last_group_msec = now
			return true
	return false


func _center_camera_on_selection() -> void:
	var selection := ManagerLocator.get_selection_manager()
	var sum := Vector2.ZERO
	var count := 0
	for hero in _heroes:
		if selection.is_selected(hero.stats.hero_id):
			sum += hero.global_position
			count += 1
	if count > 0:
		_camera.focus_on(sum / count)
